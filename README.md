# chirper-app-reverse-proxy

- The chirper-app-reverse-proxy service will help add another layer between the frontend and backend APIs so that the frontend only uses a single endpoint and doesn't realize it's deployed separately. This is one of the approaches and not necessarily the only way to deploy the services.
- Another reason we followed this approach is because we can easily manage the SSL for this service instead of managing SSL certificates for all other three microservices
- The Nginx container will expose 8080 and 1443 ports. Port 8080 for HTTP/1.1 both SSL and no SSL and port 1443 is for HTTP/2 and SSL is required

# Config file

- The configuration nginx.conf, in the server section, it will route the [https://localhost:1443/user.v1.\*](https://localhost:1443/user.v1.UserService/ListUsers) requests to the `chirper-app-user-service:8000` container.
- The [http://localhost:8080/api/v0/\*](http://localhost:8080/api/v0/tweets/limit/30/next_key/) requests to the `chirper-app-tweet-service:6060` container.
- The [http://localhost:9000/api/v0/\*](http://localhost:9000/api/v0/tweets/limit/30/next_key/) requests to the `chirper-app-image-filter-service:9000` container.
- All grpc connections are handled at port 1443 as well

## Useful links

- [https://www.nginx.com/blog/running-non-ssl-protocols-over-ssl-port-nginx-1-15-2/](https://www.nginx.com/blog/running-non-ssl-protocols-over-ssl-port-nginx-1-15-2/)
- [https://www.nginx.com/blog/deploying-nginx-plus-as-an-api-gateway-part-1/](https://www.nginx.com/blog/deploying-nginx-plus-as-an-api-gateway-part-1/)
