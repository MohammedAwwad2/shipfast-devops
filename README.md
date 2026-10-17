# ShipFast DevOps

ShipFast is a small Express service with a local bootstrap script and an Ansible
deployment exercise.

## Repository layout

```text
app/                  Express app, static page, and automated tests
advanced/ansible/     Inventory, playbook, and systemd service template
bootstrap.sh          Checks local tools and installs app dependencies
```

## Local development

Requirements: Node.js 22 or newer and npm. Docker is optional for the local
bootstrap.

```bash
bash bootstrap.sh
cd app
npm test
npm start
```

The service listens on port 3000 by default. Set `PORT` to override it, for
example `PORT=8080 npm start` in Bash. Available endpoints are `/health`,
`/api/info`, and `/metrics`.

## Ansible deployment

The playbook targets the `shipfast` group in `advanced/ansible/inventory.ini`.
From that directory, run:

```bash
ansible-playbook -i inventory.ini playbook.yml -e app_port=3001 -K
```

The playbook installs the app as a systemd service and checks its health
endpoint. On WSL, a checkout under `/mnt/c` may cause Ansible to ignore the local
`ansible.cfg` because of mount permissions; pass `-i inventory.ini` explicitly
as shown above. The target must support systemd and allow sudo privilege
escalation.
