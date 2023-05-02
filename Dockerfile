FROM nginx:alpine

COPY api_json_errors.conf /etc/nginx
COPY nginx.conf /etc/nginx/nginx.conf