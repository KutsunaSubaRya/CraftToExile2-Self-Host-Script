# TODO: replace with your own domain
screen -dmS tunnel bash -c 'cloudflared tunnel route dns minecraft your_domain.com; cloudflared tunnel --name minecraft --url tcp://127.0.0.1:25565'