#!/bin/sh
sudo wget https://github.com/nginxinc/nginx-asg-sync/releases/download/v0.2-1/nginx-asg-sync-0.2-1.amzn1.x86_64.rpm
sudo yum install nginx-asg-sync-0.2-1.amzn1.x86_64.rpm -y
sudo rm nginx-asg-sync-0.2-1.amzn1.x86_64.rpm

cat > /tmp/default.conf <<EOF
upstream app-one {
  zone app-one 64k;
  state /var/lib/nginx/state/app-one.conf;
}

upstream app-two {
  zone app-two 64k;
  state /var/lib/nginx/state/app-two.conf;
}

server {
  listen 80;

  status_zone app;

  location / {
    root /usr/share/nginx/html;
  }

  location /app-one {
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_pass http://app-one/;
  }

  location /app-two {
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$remote_addr;
    proxy_pass http://app-two/;
  }
}

server {
  listen 8080;

  location /api {
    api write=on;
  }

  location /dashboard.html {
    root /usr/share/nginx/html;
  }
}
EOF

sudo mv /tmp/default.conf /etc/nginx/conf.d/default.conf
sudo nginx -s reload

cat > /tmp/aws.yaml <<EOF
region: us-west-1
api_endpoint: http://127.0.0.1:8080/api
sync_interval_in_seconds: 5
upstreams:
  - name: app-one
    autoscaling_group: ngx-oss-1-autoscaling
    port: 80
    kind: http
  - name: app-two
    autoscaling_group: ngx-oss-2-autoscaling
    port: 80
    kind: http
EOF

sudo mv /tmp/aws.yaml /etc/nginx/aws.yaml
sudo start nginx-asg-sync
