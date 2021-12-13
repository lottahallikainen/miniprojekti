# miniprojekti - Lotta Huhta
Haaga-helian palvelinten hallinnan kurssin miniprojekti

Lisenssi: GPL3.0

Projektin tarkoituksena on luoda sisäverkon käyttäjille tiedostojen jako palvelin, sekä windowsin active directory-toimintoja vastaava palvelin linux ymppäristöön,
jolla mahdollistetaan domain-käyttäjien käyttö sekä domain-nimen käyttö.

Projektin vaihe: Beeta
tämän hetkinen vaihe on todennettu toimivaksi UBUNTU 20.04 alustalla, joita hallitaan DEBIAN Bullseye 11 koneelta. Kaikki koneet ovat olleet virtuaalikoneita VirtualBox ympäristössä.

Olemassa olevat toiminnallisuudet:
- Tiedostopalvelin asennettu ja alustettu
- ADDC-palvelin asennettu ja alustettu

Vielä lisättävät toiminnallisuudet:
- Tiedostopalvelimen liittäminen domainiin ja käyttäjä ja ryhmäkohtaisten jakovarantojen luominen
- Käyttäjien ja käyttäjäryhmien luominen oikeuksineen yms.
- Tietokoneiden liittäminen domainiin

Kuvia onnistuneista asennuksista:

![kuva](https://user-images.githubusercontent.com/82219338/145791283-c84fca9c-7c41-4950-a7c6-f290b0b4d2b1.png)![kuva](https://user-images.githubusercontent.com/82219338/145791380-8b33bc56-43ad-462b-808d-0bd48c3b7b30.png)![kuva](https://user-images.githubusercontent.com/82219338/145791415-f9a4c4bb-ac2b-4a0e-b79d-73d4bb8fb969.png)

# Käyttöönottohje
Vaatimukset:
- Salt-minion ja Salt-master ohjelmat on asennettu ennakkoon ja konfiguroitu oikein.
- Salt-minion on UBUNTU 20.04 kone
- Koneiden käyttämä palomuuri on UFW

Kopioi tämän projektin tiedostot allaolevan mukaisesti master koneen /srv/salt/ hakemistoon:
- /srv/salt/samba/smb.conf
- /srv/salt/samba/interfaces
- /srv/salt/samba/resolv.conf
- /srv/salt/samba/NetworkManager.conf
- /srv/salt/samba/hosts
- /srv/salt/sambaaddc.sls
- /srv/salt/samba.sls

Kyseiset tiedostot on syytä muokata omaan ympäristöön sopivaksi (ip-osoitteet, dns-osoitteet, domainit, salasanat)

Aja masterilta komennot:

```
sudo salt '[minion1]' state.apply samba
sudo salt '[minion2]' state.apply sambaaddc

```

Toisella koneella tulisi nyt toimia tiedostopalvelin ja toisella ADDC palvelin. Ei ole suositeltavaa ajaa molempia samaan koneeseen.



# PROJEKTIN ESITTELY
# Tiedostopalvelin
Käytetyt  ohjeet:

https://ubuntu.com/tutorials/install-and-configure-samba#2-installing-samba

https://newbedev.com/automatically-enter-input-in-command-line

https://superuser.com/questions/271034/list-samba-users

salt dokumentaatio

Miniprojektini ensimmäisessä osassa saltilla otetaan käyttöön paikallisen verkon tiedostopalvelin Samba, jolla mahdollistetaan tiedostojen jakaminen sisäverkossa.
Tein tilatiedoston samba.sls:
```
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
```

Ehto palomuurikomentoon on saatu tarkastelemalla tiedostoja user.rules ja user6.rules joihin komento ``sudo ufw allow samba`` tekee muutoksia:


![kuva](https://user-images.githubusercontent.com/82219338/145058612-5240a2e3-506d-4e9e-92de-de8e3f9315ce.png)


Tiedostoja tarkastelemalla huomataan, että alla olevat rivit lisätään niihin:
```
user.rules:

### tuple ### allow udp 137,138 0.0.0.0/0 any 0.0.0.0/0 Samba - in
-A ufw-user-input -p udp -m multiport --dports 137,138 -j ACCEPT -m comment --comment 'dapp_Samba'

### tuple ### allow tcp 139,445 0.0.0.0/0 any 0.0.0.0/0 Samba - in
-A ufw-user-input -p tcp -m multiport --dports 139,445 -j ACCEPT -m comment --comment 'dapp_Samba'

user6.rules:

### tuple ### allow udp 137,138 0.0.0.0/0 any 0.0.0.0/0 Samba - in
-A ufw-user-input -p udp -m multiport --dports 137,138 -j ACCEPT -m comment --comment 'dapp_Samba'

### tuple ### allow tcp 139,445 0.0.0.0/0 any 0.0.0.0/0 Samba - in
-A ufw-user-input -p tcp -m multiport --dports 139,445 -j ACCEPT -m comment --comment 'dapp_Samba'
```
/srv/salt/samba/smb.conf tiedosto on vakio smb.conf tiedosto, jonka perään on lisätty rivit:
```
[sambashare]
    comment = Local file share
    path = /home/samba/sambashare
    read only = no
    browsable = yes
```
Ajoin tilan komennolla:
```
sudo salt 'ubuntumin' state.apply samba
```
Tila ajettiin onnistuneesti:

![kuva](https://user-images.githubusercontent.com/82219338/145059119-5d7dec65-36a9-415f-ad3f-9a69f02af049.png)

ja uudelleen ajo ei aiheuttanut muutoksia uudelleen:

![kuva](https://user-images.githubusercontent.com/82219338/145059217-68e826b5-0a51-4884-9812-c964c68b2f60.png)

Kokeilin palvelimen toimivuutta kolmannelta virtuaalikoneelta:

![kuva](https://user-images.githubusercontent.com/82219338/145059294-250e3503-08cd-4b95-9a49-84402685144a.png)

![kuva](https://user-images.githubusercontent.com/82219338/145059342-6ec620fe-d300-418d-bdd1-f2cfb27d1c3a.png)

![kuva](https://user-images.githubusercontent.com/82219338/145059381-887dd808-1f03-4482-89db-df479fcdab20.png)

Onnistui!

# ADDC-palvelin
Käytetyt ohjeet:

https://sysadmins.co.za/setup-domain-controller-on-linux-using-samba-4/

https://wiki.archlinux.org/title/Samba/Active_Directory_domain_controller

https://www.techrepublic.com/article/how-to-deploy-samba-on-linux-as-an-active-directory-domain-controller/

https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller

https://www.tecmint.com/install-samba4-active-directory-ubuntu/

https://askubuntu.com/questions/623940/network-manager-how-to-stop-nm-updating-etc-resolv-conf

https://www.tecmint.com/set-add-static-ip-address-in-linux/

https://wiki.samba.org/index.php/Linux_and_Unix_DNS_Configuration

https://wiki.samba.org/index.php/Samba_Internal_DNS_Back_End#Troubleshooting

Salt dokumentaatio

Tein tilatiedoston nimeltä sambaadc.sls:

```
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
```
Ajettiin komennolla:
```
sudo salt 'dc1' state.apply sambaaddc
```

toimi:

![kuva](https://user-images.githubusercontent.com/82219338/145792567-1a43b958-42fc-4bc3-a77e-f06cc938405b.png)

Muutoksia ei tapahtunut seuraavien tilojen remove_conf ja disable_samba_services toimesta, koska alustettavassa koneessa ei ole ollut samba tai kerberosta asennettuna.

Nimipalvelin toimii:

![kuva](https://user-images.githubusercontent.com/82219338/145792642-3a199caf-d11b-408a-be05-053f84762de5.png)

Kerberos domain-käyttäjän autentikointi toimii:

![kuva](https://user-images.githubusercontent.com/82219338/145792723-cb12c6f8-520a-48e9-b80c-b7cb95d31982.png)

Uudelleen ajaminen ei aiheuttanut muutoksia:

![kuva](https://user-images.githubusercontent.com/82219338/145792785-a0c773f8-bbb5-4a49-981a-1e2181e39e15.png)

Haasteet: 

Pääasiassa haasteet ilmenivät manuaalisen asennuksen yhteydessä.
Yhtenä haasteena oli saada resolv.conf-tiedoston automaattiset päivitykset pois. Ongelman ratkaisuna oli päivittää NetworkManager.conf-tiedostoa.
Toinen ongelma oli saada asennettu ADDC-palvelu toimimaan kunnolla. Ratkaisuna oli poistaa system.resolved-palvelu pois käytöstä.
Kolmantena ongelmana oli asettaa samba-käyttäjälle salasana automaattisesti. Ratkaisuna oli käyttää komentoa ``yes``, joka syöttää annettua merkkijonoa loputtomasti.
Saltin puolelta haasteet liittyivät lähinnä syntaksivirheisiin, joiden ongelmat selvisivät perehtymällä saltin dokumentaatioon.

Arvio projektiin kuluneesta ajasta: 30 tuntia (projektin aiheeseen perehtyminen, manuaaliset asennukset ja niiden yhteydessä tulleiden ongelmien ratkaisu, toteutus saltilla ja raportin kirjoittaminen)


