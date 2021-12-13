#Vaihdetaan palvelin koneen nimeksi dc1
change_to_dc1:
  cmd.run:
    - name: sudo hostnamectl set-hostname dc1
    - unless:
      - hostname | grep 'dc1'

#Asetetaan kiinteät IP-asetukset koneelle
/etc/network/interfaces:
  file.managed:
    - source: salt://samba/interfaces

#Valmistellaan resolv.conf tiedosto
/etc/resolv.conf:
  file.managed:
    - source: salt://samba/resolv.conf
    - follow_symlinks: False

#Varmistetaan ettei networkamanager päivitä resolv.conf tiedostoa automaattisesti
/etc/NetworkManager/NetworkManager.conf:
  file.managed:
    - source: salt://samba/NetworkManager.conf

#Varmistetaan ettei sambapalvelut ole päällä, unless-ehdon HUHTAKOTI.LAN ja huhtakoti.lan syytä muuttaa omaan ympäristöön sopivaksi
disable_samba_services:
  service.dead:
    - enable: False
    - services:
      - samba-ad-dc
      - smbd
      - nmbd
      - winbind
    - unless:
      - cat /etc/samba/smb.conf | grep 'rfc2307'
      - cat /etc/krb5.conf | grep 'HUHTAKOTI.LAN'
      - cat /etc/krb5.conf | grep 'huhtakoti.lan'

#Varmistetaan että oikeat hostit näkyy
/etc/hosts:
  file.managed:
    - source: salt://samba/hosts

#Varmistetaan ettei koneella ole samban tai kerberoksen konfiguorointitiedostoja, unless-ehdon HUHTAKOTI.LAN ja huhtakoti.lan syytä muuttaa omaan ympäristöön sopivaksi
remove_confs:
  file.absent:
    - names:
      - /etc/samba/smb.conf
      - /etc/krb5.conf
    - unless:
      - cat /etc/samba/smb.conf | grep 'rfc2307'
      - cat /etc/krb5.conf | grep 'HUHTAKOTI.LAN'
      - cat /etc/krb5.conf | grep 'huhtakoti.lan'


#Asennetaan tarpeelliset ohjelmat
install_softwares:
  pkg.installed:
    - pkgs:
      - samba
      - krb5-user
      - krb5-config
      - winbind
      - libpam-winbind
      - libnss-winbind

#Poistetaan samban konfiguraatioteidosto, jotta seuraava tila voi onnistua, unless-ehdon HUHTAKOTI.LAN ja huhtakoti.lan syytä muuttaa omaan ympäristöön sopivaksi
remove_smb.conf:
  file.absent:
    - name: /etc/samba/smb.conf
    - unless:
      - cat /etc/samba/smb.conf | grep 'rfc2307'
      - cat /etc/krb5.conf | grep 'HUHTAKOTI.LAN'
      - cat /etc/krb5.conf | grep 'huhtakoti.lan'

#Ajetaan asennuskomento samballe, unless-ehdon HUHTAKOTI.LAN ja huhtakoti.lan syytä muuttaa omaan ympäristöön sopivaksi, Myös suoritettavan komennon realm, domain ja adminpass syytä muuttaa omaan ympäristöön sopivaksi
install_samba_addc:
  cmd.run:
    - name: sudo samba-tool domain provision --server-role=dc --use-rfc2307 --dns-backend=SAMBA_INTERNAL --realm=HUHTAKOTI.LAN --domain=HUHTAKOTI --adminpass=ErittainVahv4
    - unless:
      - cat /etc/samba/smb.conf | grep 'rfc2307'
      - cat /etc/krb5.conf | grep 'HUHTAKOTI.LAN'
      - cat /etc/krb5.conf | grep 'huhtakoti.lan'

#Luodaan symbolinen linkki oikeaan krb5.conf tiedostoon
/etc/krb5.conf:
  file.symlink:
    - target: /var/lib/samba/private/krb5.conf
    - force: True
    - backupname: /etc/krb5.conf.initial

#Asennetaan smbclient
smbclient:
  pkg.installed

#Poistetaan systemd-resolved käytöstä
systemd-resolved:
  service.dead:
    - enable: False

#Sammutetaan tarpeettomat palvelut
disable_services:
  service.dead:
    - enable: False
    - names:
      - smbd
      - nmbd
      - winbind

#Käynnistetään samba-ad-dc
unmask_samba-ad-dc:
  service.unmasked:
    - name: samba-ad-dc
enable_samba-ad-dc:
  service.running:
    - name: samba-ad-dc
    - enable: True

#Uudelleen käynnistys
reboot:
  cmd.run:
    - onchanges:
      - file: remove_smb.conf
