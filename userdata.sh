#!/bin/bash
curl -fOL https://github.com/coder/code-server/releases/download/v${version}/code-server_${version}_amd64.deb
sudo dpkg -i code-server_${version}_amd64.deb
sudo systemctl enable --now code-server@ubuntu
sleep 30
sed -i.bak 's/auth: password/auth: none/' /home/ubuntu/.config/code-server/config.yaml
sed -i.bak 's/bind-addr: 127.0.0.1:8080/bind-addr: 0.0.0.0:8080/' /home/ubuntu/.config/code-server/config.yaml
sudo systemctl restart code-server@ubuntu
sudo -u ubuntu code-server --install-extension amazonwebservices.amazon-q-vscode
sudo systemctl restart code-server@ubuntu
