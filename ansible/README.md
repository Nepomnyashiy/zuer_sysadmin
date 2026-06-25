# OSNOVA Server Bootstrap

## Safety First

Preferred local run mode: start Ansible itself with `sudo`. This avoids Ansible
timeouts on localized sudo prompts like `Пароль:`.

Run every change in check mode before applying:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml --check --diff
```

Apply only after the check output is understood:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml
```

Alternative mode, only if sudo timestamp caching works in your terminal:

```bash
sudo -v
ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml --check --diff
```

## Required Before Apply

1. Add the admin SSH key:

```bash
mkdir -p /home/nsadmin/.ssh
chmod 700 /home/nsadmin/.ssh
nano /home/nsadmin/.ssh/authorized_keys
chmod 600 /home/nsadmin/.ssh/authorized_keys
```

If `authorized_keys` is empty, the playbook continues but skips SSH hardening.
This avoids locking you out. Add a real public key from your Windows, Ubuntu, or
Android SSH client, then rerun the playbook to apply key-only SSH.

2. Recheck disk UUIDs before applying:

```bash
lsblk -f
```

Current variables are already filled from the 2026-06-25 local scan:

- `ufiles_uuid`
- `x_files_uuid`
- `mega_files_uuid`

3. Confirm the storage mounts are writable before expecting Nextcloud to see
   them:

```bash
findmnt /mnt/ufiles /srv/storage/x-files /srv/storage/mega-files
```

If any of those targets shows `ro`, fix the filesystem or unmount the desktop
auto-mount first. The bootstrap now stops on read-only storage instead of
silently continuing.

4. Optional: put Nextcloud secrets in Ansible Vault if you do not want generated
   first-run secrets:

```bash
ansible-vault create ansible/group_vars/vault.yml
```

Expected variables:

```yaml
vault_nextcloud_admin_password: "..."
vault_nextcloud_db_password: "..."
vault_nextcloud_db_root_password: "..."
```

Run with:

```bash
ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml --ask-become-pass --ask-vault-pass
```

## Notes

- RDP is installed but not opened to the whole internet.
- Nextcloud binds to `127.0.0.1:18080` by default. Publish it through a reverse
  proxy after a domain/TLS plan is selected.
- NTFS storage disks are mounted with owner UID `33` for the Nextcloud container
  and group GID `1999` for local `storage` group access.
- The storage section fails fast when a mountpoint already exists but is
  read-only, because Nextcloud external storage is not safe to configure on top
  of a `ro` filesystem.
- If Nextcloud secrets are left as placeholders, the playbook generates strong
  first-run values and stores them only in `/opt/nextcloud/nextcloud.env` with
  mode `0600`.
- The playbook does not format disks and does not start commercial project
  stacks automatically.

## Publish godny.tech through Traefik

Use the focused web publishing playbook after bootstrap has prepared Docker,
storage, and the existing Nextcloud stack:

```bash
cd /run/media/nsadmin/godny_soft/soft/sysadmin
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml --check --diff
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml
```

This playbook creates `/srv/proxy/traefik`, publishes the existing
`/opt/nextcloud` stack as `https://cloud.godny.tech`, and writes the operational
registry under `/srv/registry`. It does not create a second Nextcloud stack and
does not remove Docker containers or volumes.

After apply, verify:

```bash
sudo ufw status verbose
sudo docker ps
curl -I https://cloud.godny.tech
curl -I https://traefik.godny.tech
```
