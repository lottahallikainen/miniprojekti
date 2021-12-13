# Varmistetaan, että käyttäjä Samba on olemassa. Käyttäjän nimi voi olla muukin.
create_samba_user:
  user.present:
    - name: samba
    - password: samba
    - hash_password: True

# Varmistetaan, että samba on asennettuna ja että edellisessä kohdassa luodulle käyttäjälle löytyy kansio sambashare
install_samba:
  pkg.installed:
    - name: samba
  file.directory:
    - name: /home/samba/sambashare/
    - force: True

# Sallitaan samban liikenne palomuurinläpi, mutta vain jos kyseisiä palomuurisääntöjä ei ole jo asetettu 
allow_samba:
  cmd.run:
    - name: ufw allow samba
    - unless:
      - cat /etc/ufw/user.rules | grep 'dapp_Samba' 

# Luodaan aikaisemmin varmistetulle käyttäjälle sambatunnus ja salasana, mutta vain jos sellaista ei ole jo luotu
create_sambapassword:
  cmd.run:
    - name: yes samba|sudo smbpasswd -a samba
    - unless:
       - pdbedit -W -L|grep 'samba'

# Konfiguroidaan samba käyttäen master-koneen konfiguraatiotiedostoa ja käynnistetään palvelu uudestaan
conf_samba:
  file.managed: 
    - name: /etc/samba/smb.conf
    - source: salt://samba/smb.conf
  service.running:
    - name: smbd
    - watch:
      - file: /etc/samba/smb.conf
