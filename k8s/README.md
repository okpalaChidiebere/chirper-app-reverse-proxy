# Deploying Nginx in Kubernetes

[Here](https://kubernetes.io/docs/concepts/services-networking/ingress/#name-based-virtual-hosting) is an example of an image of whey we used Ingress

## K8s environment prerequisites

- Ensure you have `cert-manager` default resources installed. Install it using the step in this [link](https://cert-manager.io/docs/installation/kubectl/#steps). WHen you install it all the default resources created like pods, services etc will all be under the namespace `cert-manager`. This version i used at this time is `v1.11.0`. The you can go ahead and create other cert-manager resources under under your own namespace. To see all resources you created under all namespace run `kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces`.
- Ensure you have [`Ingress controller`](https://kubernetes.io/docs/concepts/services-networking/ingress/#prerequisites) default resources installed. I used AWS EKS so i had to install the controller following this [link](https://kubernetes.github.io/ingress-nginx/deploy/#aws). To see how to install ingress-controller to other Cloud provider services you can see this [link](https://kubernetes.github.io/ingress-nginx/deploy/). All resources created will be under the namespace `ingress-nginx`. The controller version i used during this time was `v1.7.0`. There are other type of Ingress Controllers other than nginx; see [here](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/). **WHY INGRESS? :** we needed an ingress because instead of having to expose all services to the outside world and have different A-records and LoadBalancer url, we can just have one A-record and then use Ingress rules to call different services based on the path.

## Creating DNS-01 solver

For this application, i used HTTP-01 solver in with the Issuer to create tls certificates. This is good but the only problem is that it does not support wildcard certificates; bacially. You may want to use wildcard certificates on Ingress resource in any namespace. To use we will need to create a secret that contains an IAM user (either admin access or just an iam [role for Route53](https://cert-manager.io/docs/configuration/acme/dns01/route53/#set-up-an-iam-role)) **aws_secret_access_key**. You can see this in your `cat ~/.aws/credentials`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: prod-route53-credentials-secret
type: Opaque
data:
  secret-access-key: nUNx1MXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX= # aws_secret_access_key in base64. See https://aws.github.io/aws-sdk-go-v2/docs/configuring-sdk/#specifying-profiles
```

On your Issuer we add the dns01 solver like

```yaml
...
kind: Issuer # use CLusterIssuer if you want to share
spec:
  acme:
    ...
    solvers:
      # we are using AWS. Thats why we use Route53. See the link below how how to configure for other Cloud Services K8s environment
      # https://cert-manager.io/docs/configuration/acme/dns01/
      - dns01:
          route53:
            region: ca-central-1
            hostedZoneID: ZO17XXXXXXXXXXXXX # gotten from the aws console
            accessKeyID: AKIAXXXXXXXXXXXXXX  # aws_access_key_id of thesame user as the aws_secret_access_key
            secretAccessKeySecretRef:
              name: prod-route53-credentials-secret # ensure this secret is in thesame namespace as this 'Issuer'
              key: secret-access-key
        selector:
          dnsZones:
            - "*.laundrykya.com"
            - "laundrykya.com"
```

In the Ingress config you can now generate cert like

```yaml
...
Kind: Ingress
...
spec:
  ingressClassName: nginx # this class ...
  tls:
    - hosts:
        - "*.laundrykya.com"
      secretName: wildcard.laundrykya.com # certificate and secret will be generated based on this name
   ...
```

See this [article](https://faun.pub/wildcard-k8s-4998173b16c8), [Cert-Manager Issuer for Cross-Account Route 53 [ EKS ]](https://blog.opstree.com/2023/03/21/cert-manager-issuer-for-cross-account-route-53-eks/) or [here](https://cert-manager.io/docs/configuration/acme/dns01/route53/)
All these resource must be under thesame namespace. If you want to learn how to share secrets or certificate 'across' namespace see [this](https://cert-manager.io/docs/tutorials/syncing-secrets-across-namespaces/#serving-a-wildcard-to-ingress-resources-in-different-namespaces-default-ssl-certificate)

## Installing commands I used to deploy initially

- `curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/aws/deploy.yaml | kubectl apply -f -` To install ingress-controller.
- `kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml` installs cert manager
- `kubectl apply $(ls env-*.yaml | awk ' { print " -f " $1 } ')` used to apply all files that satisfies name `env-*.yaml` in a folder to k8s
- If you want to apply any of these particular yaml file to a namespace add `-n <namespace_name>`. See this [example](https://medium.com/codex/setup-multiple-nginx-ingress-controllers-on-eks-clusters-4e4dc37f6974) of why you need and how it can happen
- You can see all these files in github open source codes

## Adding CORS to Ingress Nginx in k8s

Another approach is to add this

```yaml
nginx.ingress.kubernetes.io/enable-cors: "true"
nginx.ingress.kubernetes.io/cors-allow-methods: "PUT, GET, POST, OPTIONS"
nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
nginx.ingress.kubernetes.io/configuration-snippet: |
  more_set_headers "Access-Control-Allow-Origin: $http_origin";
```

See more nginx annotations [here](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)

## Debugging K8 Commands I used

- `kubectl get pods -A` Get all pods in all namespace
- `kubectl get services -A` Get all services in all namespace
- `kubectl exec ingress-nginx-controller-{UNIQUE-ID} -n ingress-nginx -- cat /etc/nginx/nginx.conf` view ingress-nginx-controller config file.
- `kubectl exec ingress-nginx-controller-{UNIQUE-ID} -n ingress-nginx -- nginx -s reload reloads container` reloads the nginx
- `kubectl logs ingress-nginx-controller-{UNIQUE-ID} -n ingress-nginx` View logs in the ingress-controller
- `kubectl get secret -n cert-manager` Get all secrets created in the cert-manager namespace
- `kubectl get secret <secret-name> -n cert-manager -o yaml` which will dump it out in YAML form and usually includes the encoded secret values
- `kubectl get secret <secret-name> -n cert-manager -o jsonpath='{.data.\*}'` gives you just the secret key
- `kubectl describe ingress <ingress-name>` Describe an ingress to see namespaces and also confirm that the acme http01 challenges work to issue the right certs. You can also get the acme challenge endpoint as well when you enable tls
- `kubectl get ingress <ingress-name>`
- `kubectl get certificates` get all certificate in the default namespace to see an overview of if the certificate is ready or not. You can add the `-o wide` to see more brief text reasons
- `kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges -n default` get everything you created that related to cert-manager in the default namespace. Any resource you in k8s without explicitly defining the namespace, it will be created in the default namespace. use `--all-namespaces` if you want to see these in all namespace
- `kubectl describe certificate chirper-app-tls` Describe certificate to see the expire time as well as events on when certificate is issued or when there is a problem
- `curl http://testb-dev.laundrykya.com/.well-known/acme-challenge/78ENkMbvmaWow_PWru31Tn9iFdSmtD4CXCO6iwgwbY0` test the achme challenge endpoint yourself
- `kubectl get challenges -o wide` get all challenges/solver pending or failing that causes certificate issuing to be delayed or fail. Ideally you don't want to see anything here :)
- `kubectl get certificate chirper-app-tls -o yaml` View yaml config for a certificate to verify that it is create dunder the namespace you want
- `kubectl set image deployment frontend frontend=[Dockerhub-username]/udagram-frontend:v6` Rolling update the containers of "frontend" deployment
- `kubectl get pods --all-namespaces | grep Running | wc -l` To see the total number of pods running
- `kubectl get nodes -o yaml | grep pods` to see the limit of pods you can run in this cluster
- `kubectl describe nodes`
- One reason a newly created pod might be stuck in **pending** `STATUS` is to to insufficient worker nodes and worker nodes being out of capacity. [See](https://containersolutions.github.io/runbooks/posts/kubernetes/0-nodes-available-insufficient/)

```bash
# when you run `kubectl describe pod <pod-name>`
[...]
Events:
  Type     Reason            Age                    From               Message
  ----     ------            ----                   ----               -------
  Warning  FailedScheduling  4m50s (x2 over 9m53s)  default-scheduler  0/1 nodes are available: 1 Too many pods. preemption: 0/1 nodes are available: 1 No preemption victims found for incoming pod.
```

You basically need to autoscale as required like:

```bash
eksctl scale nodegroup --name=<managed-worker-node-name> --cluster=<managed-cluster-name> --nodes=4 --nodes-min=1 --nodes-max=5
```

This was one of the way i fixed it. See the last answer [here](https://stackoverflow.com/questions/61724527/eksctl-update-node-definitions-via-cluster-config-file-not-working), [docs](https://eksctl.io/usage/eks-managed-nodes/#existing-clusters), [another one](https://eksctl.io/usage/managing-nodegroups/)

- `kubectl autoscale deployment backend-user --cpu-percent=70 --min=3 --max=5` autoscaling a deployment pod
- List Worker Nodes

```bash
# List EKS clusters
eksctl get cluster

# List NodeGroups in a cluster
eksctl get nodegroup --cluster=<clusterName>

# List Nodes in current kubernetes cluster
kubectl get nodes -o wide

# Our kubectl context should be automatically changed to new cluster
kubectl config view --minify
```

- Look at what's there inside the running container. Open a Shell to a running container as:

```bash
kubectl get pods
# Assuming "backend-feed-68d5c9fdd6-dkg8c" is a pod
kubectl exec --stdin --tty backend-feed-68d5c9fdd6-dkg8c -- /bin/bash
# See what values are set for environment variables in the container
printenv | grep POST
# Or, you can try "curl <cluster-IP-of-backend>:8080/api/v0/feed " to check if services are running.
# This is helpful to see is backend is working by opening a bash into the frontend container
```

- `kubectl get services -n nginx-ingress` get services in the nginx-ingress namespace. Here you want to get the LB url
- [https://stackoverflow.com/questions/64260214/sending-http-request-from-kubernetes-pod-through-ingress-service-to-another-pod](https://stackoverflow.com/questions/64260214/sending-http-request-from-kubernetes-pod-through-ingress-service-to-another-pod)
- [https://stackoverflow.com/questions/47579269/unable-to-remove-kubernetes-pods-for-nginx-ingress-controller](https://stackoverflow.com/questions/47579269/unable-to-remove-kubernetes-pods-for-nginx-ingress-controller)

## Ingress vs. ClusterIP vs. NodePort vs. LoadBalancer

- [Article](https://www.tecmint.com/deploy-nginx-on-a-kubernetes-cluster/)
- [Article](https://stackoverflow.com/questions/41509439/whats-the-difference-between-clusterip-nodeport-and-loadbalancer-service-types)
- [Article](https://www.solo.io/topics/kubernetes-api-gateway/kubernetes-ingress/)

## Certificate Status

Below is an example of **Event** when the certificate has been successfully issued

```bash
...
Events:
  Type    Reason     Age    From                                       Message
  ----    ------     ----   ----                                       -------
  ...
  Normal  Issuing    20m    cert-manager-certificates-issuing          Issued temporary certificate  # you can still use https but the certificate is insecure just yet and invalid. You will have to wait for some time :(
  Normal  Issuing    112s   cert-manager-certificates-issuing          The certificate has been successfully issued # this event means that the certificate is now valid. All green :)
```

Note that cert manager will issue a Fake Cert that is invalid in the meantime while creating a real valid one. If you see details about the fake cert in browser the **Cert (Issued To) CN** will be 'Kubernetes Ingress Controller Fake Ingress' and the **Issuer (Issued By) CN** 'Kubernetes Ingress Controller Fake Ingress'. When the certificate is ready and all green you see the status below when you run k8s command to describe the certificate

```bash
# When the certificate is ready to go
Status:
  Conditions:
    ...
    Reason:                Ready
    Status:                True
    Type:                  Ready
    ...
...
```

You will see this when the certificate is issuing. You might have to wait a bit

```bash
Status:
  Conditions:
    ...
    Reason:                      RequestChanged
    Status:                      True
    Type:                        Issuing
```

**NOTE:** Ensure the Ingress, Issuers are created in the same namespace as the Certificates you want to create as well as the k8s secret you give your solver if you are using DNS-01 are all under thesame namespace. See this [article](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-with-cert-manager-on-digitalocean-kubernetes)

## EKS with K8s

- [Multiple environments (Staging, QA, production, etc) with Kubernetes. Very goog read](https://stackoverflow.com/questions/43212836/multiple-environments-staging-qa-production-etc-with-kubernetes)

## ACME Issuer

- [Creating a Basic ACME Issuer](https://cert-manager.io/docs/configuration/acme/#creating-a-basic-acme-issuer)

## Why I need to by a domain name in AWS to use it in Ingress

I ran into an issue were I was directly hitting the external IP of the Nginx ingress controller and i kept getting a **404** from Nginx controller. This is because testb-dev.laundrykya.com and testa-dev.laundrykya.com is the Domain (host) in the ingress rule and the Nginx ingress controller checks for that.

```bash
curl -i  https://aaa71bxxxxx-11xxxxx10.us-east-2.elb.amazonaws.com/api/v0/tweets/limit/30/next_key/ # 404
```

Web Side:

```js
fetch(
  "http://aaa71bxxxxx-11xxxxx10.us-east-2.elb.amazonaws.com/api/v0/tweets/limit/30/next_key//api/v0/tweets/limit/30/next_key/",
  { method: "GET" }
)
  .then((response) => response.json())
  .then((response) => console.log(response));
//this fails because 'aaa71bxxxxx-11xxxxx10.us-east-2.elb.amazonaws.com' is not a supported host in the ingress rule
let url = new URL(
  "http://aaa71bxxxxx-11xxxxx10.us-east-2.elb.amazonaws.com/api/v0/tweets/limit/30/next_key//api/v0/tweets/limit/30/next_key/"
);
console.log(url.host); // "aaa71bxxxxx-11xxxxx10.us-east-2.elb.amazonaws.com"
```

To solve this we can curl this

```bash
curl -i -H "Host: testa-dev.laundrykya.com"  https://aaa71bxxxxx-11xxxxx10.us-east-2.elb.amazonaws.com/api/v0/tweets/limit/30/next_key/ # works! or you can use postman.
```

However in the browser, we cannot pass in a custom Host as header in fetch requests. This is forbidden and the request will fail.

```js
//This does not work
fetch(
  "https://aaa71bxxxxx-11xxxxx10.us-east-2.elb.amazonaws.com/api/v0/tweets/limit/30/next_key/",
  {
    method: "GET",
    headers: {
      Host: "testa-dev.laundrykya.com", //FORBIDDEB header to modify. browser will not fail this request
    },
  }
)
  .then((response) => response.json())
  .then((response) => console.log(response));
```

So we had to [buy our own domain](https://seed.run/blog/how-to-buy-a-domain-name-on-amazon-route-53-for-my-serverless-api.html) with (CNAME) and set up custom A-records (alias) and then how that record route traffic to the Load Balancer (Externam IP). See this [link](https://repost.aws/knowledge-center/route-53-create-alias-records) for how to create an alias record or watch this [video](https://www.youtube.com/watch?v=-JF2ukmW3i8). You can Read this [article](https://repost.aws/knowledge-center/eks-access-kubernetes-services) as well. An alias record is a Route 53 extension to DNS. It's similar to a CNAME record, but you can create an alias record both for the root domain, such as example.com, and for subdomains, such as www.example.com. (You can create CNAME records only for subdomains.) See aws [doc](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html)

## Multiple ingress Controllers

- [https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/](https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/)
- [Using multiple Ingress controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/#using-multiple-ingress-controllers)

## TroubleShooting Cert-Manager

- [Supported Releases based on K8s version](https://cert-manager.io/docs/installation/supported-releases/)
- [TroubleShooting](https://cert-manager.io/docs/troubleshooting/)
- [Troubleshooting Issuing ACME Certificates](https://cert-manager.io/v1.6-docs/faq/acme/)
- [multi-domain support, especially for route 53 challenge with different hostedzoneID](https://github.com/cert-manager/cert-manager/issues/822)
- [Tutorials](https://cert-manager.io/docs/tutorials/)
- [Kubectl plugin](https://cert-manager.io/v1.5-docs/usage/kubectl-plugin/)
- [Link an A-record to LB](https://myhightech.org/posts/20210402-cert-manager-on-eks/)

## Application LoadBalancer with Ingress

- [How do I provide external access to multiple Kubernetes services in my Amazon EKS cluster? With LoadBalancer Included](https://repost.aws/knowledge-center/eks-access-kubernetes-services])
- [https://repost.aws/knowledge-center/eks-access-kubernetes-services](https://repost.aws/knowledge-center/eks-access-kubernetes-services)
- [https://www.alibabacloud.com/help/en/container-service-for-kubernetes/latest/advanced-alb-ingress-configurations-2](https://www.alibabacloud.com/help/en/container-service-for-kubernetes/latest/advanced-alb-ingress-configurations-2)
- [https://kubernetes-sigs.github.io/aws-load-balancer-controller/v1.1/guide/walkthrough/echoserver/](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v1.1/guide/walkthrough/echoserver/)
- [https://www.stacksimplify.com/aws-eks/aws-alb-ingress/lean-kubernetes-aws-alb-ingress-basics/](https://www.stacksimplify.com/aws-eks/aws-alb-ingress/lean-kubernetes-aws-alb-ingress-basics/)
- [https://aws.amazon.com/blogs/opensource/kubernetes-ingress-aws-alb-ingress-controller/](https://aws.amazon.com/blogs/opensource/kubernetes-ingress-aws-alb-ingress-controller/)

## Protecting APIs at Network Level

- [NetworkPolicy](https://blog.cloudflare.com/moving-k8s-communication-to-grpc/)

## Nginx with HTTP/2 Support

By default the nginx-controller in uses http2 by default, you can change that if you wanted. This [article](https://www.digitalocean.com/community/tutorials/how-to-set-up-nginx-with-http-2-support-on-ubuntu-18-04) explains how i implemented this locally for reverse-proxy
