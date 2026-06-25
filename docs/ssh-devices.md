# SSH-доступ устройств к ZUER

Цель: дать доступ устройствам `qbook`, `QwackPhone`, `QwackPad` к пользователю
`nsadmin` на сервере `ZUER` без парольного production-доступа.

## Принцип

- Один Ed25519-ключ на каждое устройство.
- Приватный ключ остается только на устройстве.
- На сервер добавляется только public key.
- Парольный SSH отключается только после проверки входа со всех устройств.

## qbook / Ubuntu

Сгенерировать ключ на qbook:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/zuer_qbook_ed25519 -C "qbook nsadmin@ZUER"
chmod 600 ~/.ssh/zuer_qbook_ed25519
chmod 644 ~/.ssh/zuer_qbook_ed25519.pub
cat ~/.ssh/zuer_qbook_ed25519.pub
```

Добавить SSH config на qbook:

```text
Host zuer
    HostName 192.168.0.101
    User nsadmin
    IdentityFile ~/.ssh/zuer_qbook_ed25519
    IdentitiesOnly yes

Host zuer-public
    HostName 85.172.104.173
    User nsadmin
    IdentityFile ~/.ssh/zuer_qbook_ed25519
    IdentitiesOnly yes
```

Проверка:

```bash
ssh zuer
ssh zuer-public
```

## QwackPhone / QwackPad

В Termius или Blink:

1. Создать новый Ed25519 key.
2. Задать passphrase.
3. Назвать ключ `QwackPhone nsadmin@ZUER` или `QwackPad nsadmin@ZUER`.
4. Скопировать/export public key.
5. Не переносить private key на сервер.

Host для LAN:

```text
Host: 192.168.0.101
User: nsadmin
Port: 22
Auth: key
```

Host для интернета:

```text
Host: 85.172.104.173
User: nsadmin
Port: 22
Auth: key
```

## Добавление ключей на сервер

Рекомендуемый способ: Ansible Vault.

```bash
cd /run/media/nsadmin/godny_soft/soft/sysadmin
ansible-vault create ansible/group_vars/vault.yml
```

Минимальное содержимое:

```yaml
vault_qbook_ssh_public_key: "ssh-ed25519 AAAA... qbook nsadmin@ZUER"
vault_qwackphone_ssh_public_key: "ssh-ed25519 AAAA... QwackPhone nsadmin@ZUER"
vault_qwackpad_ssh_public_key: "ssh-ed25519 AAAA... QwackPad nsadmin@ZUER"
```

Проверить и применить ключи:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/ssh-access.yml --check --diff --ask-vault-pass
sudo ansible-playbook -i ansible/inventory.ini ansible/ssh-access.yml --ask-vault-pass
```

После успешного входа со всех устройств включить hardening:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/ssh-access.yml \
  --ask-vault-pass \
  -e ssh_enable_key_only_hardening=true
```

Старую SSH-сессию не закрывать, пока новая key-only сессия не проверена.
