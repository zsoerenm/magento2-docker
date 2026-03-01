# Magento 2 Docker

Yet another composition of Docker containers to run Magento 2.

## Features

- Support **development** and **production** environments
- Use official containers if possible
- Use Alpine Linux if possible
- Follow best practices from [Docker](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- Closely follow the installation guide from [Magento 2](https://experienceleague.adobe.com/en/docs/commerce-operations/installation-guide/overview)
- Configure SMTP server via environment variables to enable two-factor authentication (2FA) right from the start (no need to disable it)
- Easy deployment

## Containers

- PHP: magento2-php based on [php:fpm-alpine](https://hub.docker.com/_/php/)
- MariaDB: [mariadb](https://hub.docker.com/_/mariadb/)
- Nginx: magento2-nginx based on [nginxinc/nginx-unprivileged:alpine](https://hub.docker.com/r/nginxinc/nginx-unprivileged)
- Redis: [redis:alpine](https://hub.docker.com/_/redis/)
- Cron: magento2-php based on [php:fpm-alpine](https://hub.docker.com/_/php/)
- Varnish: magento2-varnish based on [varnish:alpine](https://hub.docker.com/_/varnish)
- Opensearch: [opensearchproject/opensearch](https://hub.docker.com/r/opensearchproject/opensearch)
- SSL / TLS Termination: [caddy:alpine](https://hub.docker.com/_/caddy)
- Autoheal: [willfarrell/autoheal](https://hub.docker.com/r/willfarrell/autoheal) - Automatically restarts unhealthy containers

## Getting Started

### Prerequisites

#### HTTPS during local development

Yes, this repository supports HTTPS for local development. This follows the best practice of keeping the development environment as close to the production environment as possible. Also, web browsers behave in subtly different ways on HTTP vs. HTTPS pages. The main difference: On an HTTPS page, all requests to load JavaScript from an HTTP URL are blocked [[see Let's Encrypt: Certificates for localhost](https://letsencrypt.org/docs/certificates-for-localhost/)].

The easiest way to create your own certificates is to use [mkcert](https://github.com/FiloSottile/mkcert). Generate a certificate for `localhost` and / or a named URL like `magento.local` in the `certs` directory:

```
mkcert -key-file certs/key.pem -cert-file certs/cert.pem magento.local localhost
```

The SSL / TLS termination is handled by Caddy, which will automatically use the `certs/key.pem` and `certs/cert.pem` files for HTTPS in development.

If you'd like to use a named URL like `magento.local` also make sure to add an entry to your `hosts` file (located at `/etc/hosts`):

```
127.0.0.1  magento.local
```

#### HTTPS in Production

For production deployments, this repository uses Let's Encrypt for automatic HTTPS certificate management. Caddy handles certificate provisioning and renewal automatically. The default Caddyfile is configured for production use with Let's Encrypt.

**Configuration:**

1. Set environment variables for Let's Encrypt in your production environment:

   ```bash
   export CADDY_EMAIL=your-email@example.com  # Required for Let's Encrypt notifications
   export DOMAIN=yourdomain.com                # Your production domain
   ```

2. Ensure your domain's DNS A record points to your server's IP address.

3. Deploy normally - Caddy will automatically obtain and renew certificates from Let's Encrypt.

**Note:**

- Port 80 must be accessible from the internet for Let's Encrypt HTTP-01 challenge validation.
- For local development, docker-compose.override.yml automatically uses Caddyfile.dev with mkcert certificates.

#### Download Magento source files

```shell
wget -qO- https://github.com/magento/magento2/archive/refs/tags/$(cat .magento-version).tar.gz \
	| tar xzfo - --strip-components=1 -C src/ \
	&& docker compose run --rm composer install
```

The composer container will automatically install required PHP extensions defined in the composer file.

#### Secrets Management

This setup uses Docker secrets to securely manage sensitive information like passwords. Create the following files in the `secrets/` directory:

- `secrets/db_password.txt` - Database password for Magento user
- `secrets/mysql_root_password.txt` - MySQL root password
- `secrets/admin_password.txt` - Magento admin password
- `secrets/smtp_password.txt` - SMTP server password

These secrets are automatically mounted into containers at `/run/secrets/` and used by the application.

##### Install packages via Composer

The docker-compose.yml file also ships with a Composer service.
You can use it to install packages via Composer:

```shell
docker compose run --rm composer require <package>
```

![Environments](https://github.com/zsoerenm/magento2-docker/raw/master/manual/environments.svg?sanitize=true)

##### Production

For the **production** environment it is instead recommended copying the source code into the container and omit the mount from host to container. Moreover, this repository implements the [suggested pipeline deployment](https://devdocs.magento.com/guides/v2.2/config-guide/deployment/pipeline/technical-details.html) from Magento. It enables a fast deployment with a very short offline interval compared to the conventional deployment process. See the section "From development to production environment" below for further details.

### Usage

In a development environment simply run

```shell
docker-compose up
```

and head to `http://localhost/`. You should automatically be redirected to HTTPS.

#### Environment Variables

##### PHP

Magento will be installed the first time you start the container.
The installation can be configured by environment variables.
You can find all configuration options [here](https://experienceleague.adobe.com/en/docs/commerce-operations/tools/cli-reference/commerce-on-premises#setupinstall).
Since environment variables are usually written in caps lock and with the
underscore separator, the configuration keys are transformed.
Hence, `--db-host` becomes `DB_HOST` and `--admin-user` becomes `ADMIN_USER`.

Most of the installation configuration options can also be changed after Magento has been installed (the Docker entry point will use `php bin/magento setup:config:set` internally).
See [this](https://experienceleague.adobe.com/en/docs/commerce-operations/tools/cli-reference/commerce-on-premises#setupconfigset) list for all configuration options.

Beyond that, you can also set any configuration which you would normally set in the admin backend. [Here](https://experienceleague.adobe.com/en/docs/commerce-operations/configuration-guide/deployment/examples/example-environment-variables) you will find more on how to set configurations using environment variables.

- Example: `CONFIG__DEFAULT__GENERAL__STORE_INFORMATION__NAME=Foobar` - Optional - sets config for `general/store_information/name`

**Secrets Support**: For sensitive data like passwords, you can use the `_FILE` suffix to read values from Docker secrets:

- `DB_PASSWORD_FILE=/run/secrets/db_password` - Read database password from secret file
- `ADMIN_PASSWORD_FILE=/run/secrets/admin_password` - Read admin password from secret file
- `CONFIG__DEFAULT__SYSTEM__SMTP__PASSWORD_UNENCRYPTED_FILE=/run/secrets/smtp_password` - Read SMTP password from secret file

_Note_: This is a great opportunity to get around the chicken-egg problem with two-factor authentication (2FA). Since v2.4.6
Magento ships with SMTP integration, and you can set the appropriate configuration options up front using secrets (see the docker-compose.yml file for more explanation).

If you'd like to set the language of the shop, you can do so by setting

```
LANGUAGE=en_US
```

You can list all installed languages with

```bash
docker-compose run --rm php bin/magento info:language:list
```

This should give a list similar to

<details>
<summary>
Languages
</summary>
+--------------------------+-------+
| Language                 | Code  |
+--------------------------+-------+
| English (United Kingdom) | en_GB |
| English (United States)  | en_US |
+--------------------------+-------+
</details>
For other languages, you'll need to install them.

If you'd like to set the currency of the shop, you can do so by setting

```
CURRENCY=EUR
```

You can list all available currencies with

```bash
docker-compose run --rm php bin/magento info:currency:list
```

This should give a list similar to

<details>
<summary>
Currencies
</summary>
+---------------------------------------------+------+
| Currency                                    | Code |
+---------------------------------------------+------+
| Afghan Afghani (AFN)                        | AFN  |
| Albanian Lek (ALL)                          | ALL  |
| Algerian Dinar (DZD)                        | DZD  |
| Angolan Kwanza (AOA)                        | AOA  |
| Argentine Peso (ARS)                        | ARS  |
| Armenian Dram (AMD)                         | AMD  |
| Aruban Florin (AWG)                         | AWG  |
| Australian Dollar (AUD)                     | AUD  |
| Azerbaijani Manat (1993–2006) (AZM)         | AZM  |
| Azerbaijani Manat (AZN)                     | AZN  |
| Bahamian Dollar (BSD)                       | BSD  |
| Bahraini Dinar (BHD)                        | BHD  |
| Bangladeshi Taka (BDT)                      | BDT  |
| Barbadian Dollar (BBD)                      | BBD  |
| Belarusian Ruble (BYN)                      | BYN  |
| Belize Dollar (BZD)                         | BZD  |
| Bermudan Dollar (BMD)                       | BMD  |
| Bhutanese Ngultrum (BTN)                    | BTN  |
| Bolivian Boliviano (BOB)                    | BOB  |
| Bosnia-Herzegovina Convertible Mark (BAM)   | BAM  |
| Botswanan Pula (BWP)                        | BWP  |
| Brazilian Real (BRL)                        | BRL  |
| British Pound (GBP)                         | GBP  |
| Brunei Dollar (BND)                         | BND  |
| Bulgarian Lev (BGN)                         | BGN  |
| Burmese Kyat (BUK)                          | BUK  |
| Burundian Franc (BIF)                       | BIF  |
| CFP Franc (XPF)                             | XPF  |
| Cambodian Riel (KHR)                        | KHR  |
| Canadian Dollar (CAD)                       | CAD  |
| Cape Verdean Escudo (CVE)                   | CVE  |
| Cayman Islands Dollar (KYD)                 | KYD  |
| Chilean Peso (CLP)                          | CLP  |
| Chinese Yuan (CNY)                          | CNY  |
| Colombian Peso (COP)                        | COP  |
| Comorian Franc (KMF)                        | KMF  |
| Congolese Franc (CDF)                       | CDF  |
| Costa Rican Colón (CRC)                     | CRC  |
| Croatian Kuna (HRK)                         | HRK  |
| Cuban Peso (CUP)                            | CUP  |
| Czech Koruna (CZK)                          | CZK  |
| Danish Krone (DKK)                          | DKK  |
| Djiboutian Franc (DJF)                      | DJF  |
| Dominican Peso (DOP)                        | DOP  |
| East Caribbean Dollar (XCD)                 | XCD  |
| Egyptian Pound (EGP)                        | EGP  |
| Equatorial Guinean Ekwele (GQE)             | GQE  |
| Eritrean Nakfa (ERN)                        | ERN  |
| Estonian Kroon (EEK)                        | EEK  |
| Ethiopian Birr (ETB)                        | ETB  |
| Euro (EUR)                                  | EUR  |
| Falkland Islands Pound (FKP)                | FKP  |
| Fijian Dollar (FJD)                         | FJD  |
| Gambian Dalasi (GMD)                        | GMD  |
| Georgian Kupon Larit (GEK)                  | GEK  |
| Georgian Lari (GEL)                         | GEL  |
| Ghanaian Cedi (GHS)                         | GHS  |
| Gibraltar Pound (GIP)                       | GIP  |
| Guatemalan Quetzal (GTQ)                    | GTQ  |
| Guinean Franc (GNF)                         | GNF  |
| Guyanaese Dollar (GYD)                      | GYD  |
| Haitian Gourde (HTG)                        | HTG  |
| Honduran Lempira (HNL)                      | HNL  |
| Hong Kong Dollar (HKD)                      | HKD  |
| Hungarian Forint (HUF)                      | HUF  |
| Icelandic Króna (ISK)                       | ISK  |
| Indian Rupee (INR)                          | INR  |
| Indonesian Rupiah (IDR)                     | IDR  |
| Iranian Rial (IRR)                          | IRR  |
| Iraqi Dinar (IQD)                           | IQD  |
| Israeli New Shekel (ILS)                    | ILS  |
| Jamaican Dollar (JMD)                       | JMD  |
| Japanese Yen (JPY)                          | JPY  |
| Jordanian Dinar (JOD)                       | JOD  |
| Kazakhstani Tenge (KZT)                     | KZT  |
| Kenyan Shilling (KES)                       | KES  |
| Kuwaiti Dinar (KWD)                         | KWD  |
| Kyrgystani Som (KGS)                        | KGS  |
| Laotian Kip (LAK)                           | LAK  |
| Latvian Lats (LVL)                          | LVL  |
| Lebanese Pound (LBP)                        | LBP  |
| Lesotho Loti (LSL)                          | LSL  |
| Liberian Dollar (LRD)                       | LRD  |
| Libyan Dinar (LYD)                          | LYD  |
| Lithuanian Litas (LTL)                      | LTL  |
| Macanese Pataca (MOP)                       | MOP  |
| Macedonian Denar (MKD)                      | MKD  |
| Malagasy Ariary (MGA)                       | MGA  |
| Malawian Kwacha (MWK)                       | MWK  |
| Malaysian Ringgit (MYR)                     | MYR  |
| Maldivian Rufiyaa (MVR)                     | MVR  |
| Mauritanian Ouguiya (1973–2017) (MRO)       | MRO  |
| Mauritian Rupee (MUR)                       | MUR  |
| Mexican Peso (MXN)                          | MXN  |
| Moldovan Leu (MDL)                          | MDL  |
| Mongolian Tugrik (MNT)                      | MNT  |
| Moroccan Dirham (MAD)                       | MAD  |
| Mozambican Metical (MZN)                    | MZN  |
| Myanmar Kyat (MMK)                          | MMK  |
| Namibian Dollar (NAD)                       | NAD  |
| Nepalese Rupee (NPR)                        | NPR  |
| Netherlands Antillean Guilder (ANG)         | ANG  |
| New Taiwan Dollar (TWD)                     | TWD  |
| New Zealand Dollar (NZD)                    | NZD  |
| Nicaraguan Córdoba (1988–1991) (NIC)        | NIC  |
| Nicaraguan Córdoba (NIO)                    | NIO  |
| Nigerian Naira (NGN)                        | NGN  |
| North Korean Won (KPW)                      | KPW  |
| Norwegian Krone (NOK)                       | NOK  |
| Omani Rial (OMR)                            | OMR  |
| Pakistani Rupee (PKR)                       | PKR  |
| Panamanian Balboa (PAB)                     | PAB  |
| Papua New Guinean Kina (PGK)                | PGK  |
| Paraguayan Guarani (PYG)                    | PYG  |
| Peruvian Sol (PEN)                          | PEN  |
| Philippine Peso (PHP)                       | PHP  |
| Polish Zloty (PLN)                          | PLN  |
| Qatari Riyal (QAR)                          | QAR  |
| Rhodesian Dollar (RHD)                      | RHD  |
| Romanian Leu (1952–2006) (ROL)              | ROL  |
| Romanian Leu (RON)                          | RON  |
| Russian Ruble (RUB)                         | RUB  |
| Rwandan Franc (RWF)                         | RWF  |
| Salvadoran Colón (SVC)                      | SVC  |
| Samoan Tala (WST)                           | WST  |
| Saudi Riyal (SAR)                           | SAR  |
| Serbian Dinar (RSD)                         | RSD  |
| Seychellois Rupee (SCR)                     | SCR  |
| Sierra Leonean Leone (1964—2022) (SLL)      | SLL  |
| Singapore Dollar (SGD)                      | SGD  |
| Slovak Koruna (SKK)                         | SKK  |
| Solomon Islands Dollar (SBD)                | SBD  |
| Somali Shilling (SOS)                       | SOS  |
| South African Rand (ZAR)                    | ZAR  |
| South Korean Won (KRW)                      | KRW  |
| Sri Lankan Rupee (LKR)                      | LKR  |
| St. Helena Pound (SHP)                      | SHP  |
| Sudanese Pound (SDG)                        | SDG  |
| Surinamese Dollar (SRD)                     | SRD  |
| Swazi Lilangeni (SZL)                       | SZL  |
| Swedish Krona (SEK)                         | SEK  |
| Swiss Franc (CHF)                           | CHF  |
| Syrian Pound (SYP)                          | SYP  |
| São Tomé & Príncipe Dobra (1977–2017) (STD) | STD  |
| Tajikistani Somoni (TJS)                    | TJS  |
| Tanzanian Shilling (TZS)                    | TZS  |
| Thai Baht (THB)                             | THB  |
| Tongan Paʻanga (TOP)                        | TOP  |
| Trinidad & Tobago Dollar (TTD)              | TTD  |
| Tunisian Dinar (TND)                        | TND  |
| Turkish Lira (1922–2005) (TRL)              | TRL  |
| Turkish Lira (TRY)                          | TRY  |
| Turkmenistani Manat (1993–2009) (TMM)       | TMM  |
| US Dollar (USD)                             | USD  |
| Ugandan Shilling (UGX)                      | UGX  |
| Ukrainian Hryvnia (UAH)                     | UAH  |
| United Arab Emirates Dirham (AED)           | AED  |
| Uruguayan Peso (UYU)                        | UYU  |
| Uzbekistani Som (UZS)                       | UZS  |
| Vanuatu Vatu (VUV)                          | VUV  |
| Venezuelan Bolívar (1871–2008) (VEB)        | VEB  |
| Venezuelan Bolívar (2008–2018) (VEF)        | VEF  |
| Vietnamese Dong (VND)                       | VND  |
| WIR Euro (CHE)                              | CHE  |
| WIR Franc (CHW)                             | CHW  |
| West African CFA Franc (XOF)                | XOF  |
| Yemeni Rial (YER)                           | YER  |
| Zambian Kwacha (1968–2012) (ZMK)            | ZMK  |
| Zimbabwean Dollar (1980–2008) (ZWD)         | ZWD  |
+---------------------------------------------+------+
</details>

If you'd like to set the timezone of the shop, you can do so by setting

```
TIMEZONE=Europe/Berlin
```

You can list all available timezones with

```bash
docker-compose run --rm php bin/magento info:timezone:list
```

This should give a list similar to

<details>
<summary>
Timezones
</summary>
+------------------------------------------------------------+--------------------------------+
| Timezone                                                   | Code                           |
+------------------------------------------------------------+--------------------------------+
| Acre Standard Time (America/Eirunepe)                      | America/Eirunepe               |
| Acre Standard Time (America/Rio_Branco)                    | America/Rio_Branco             |
| Afghanistan Time (Asia/Kabul)                              | Asia/Kabul                     |
| Alaska Standard Time (America/Anchorage)                   | America/Anchorage              |
| Alaska Standard Time (America/Juneau)                      | America/Juneau                 |
| Alaska Standard Time (America/Metlakatla)                  | America/Metlakatla             |
| Alaska Standard Time (America/Nome)                        | America/Nome                   |
| Alaska Standard Time (America/Sitka)                       | America/Sitka                  |
| Alaska Standard Time (America/Yakutat)                     | America/Yakutat                |
| Amazon Standard Time (America/Boa_Vista)                   | America/Boa_Vista              |
| Amazon Standard Time (America/Campo_Grande)                | America/Campo_Grande           |
| Amazon Standard Time (America/Cuiaba)                      | America/Cuiaba                 |
| Amazon Standard Time (America/Manaus)                      | America/Manaus                 |
| Amazon Standard Time (America/Porto_Velho)                 | America/Porto_Velho            |
| Anadyr Standard Time (Asia/Anadyr)                         | Asia/Anadyr                    |
| Apia Standard Time (Pacific/Apia)                          | Pacific/Apia                   |
| Arabian Standard Time (Asia/Aden)                          | Asia/Aden                      |
| Arabian Standard Time (Asia/Baghdad)                       | Asia/Baghdad                   |
| Arabian Standard Time (Asia/Bahrain)                       | Asia/Bahrain                   |
| Arabian Standard Time (Asia/Kuwait)                        | Asia/Kuwait                    |
| Arabian Standard Time (Asia/Qatar)                         | Asia/Qatar                     |
| Arabian Standard Time (Asia/Riyadh)                        | Asia/Riyadh                    |
| Argentina Standard Time (America/Argentina/Buenos_Aires)   | America/Argentina/Buenos_Aires |
| Argentina Standard Time (America/Argentina/Catamarca)      | America/Argentina/Catamarca    |
| Argentina Standard Time (America/Argentina/Cordoba)        | America/Argentina/Cordoba      |
| Argentina Standard Time (America/Argentina/Jujuy)          | America/Argentina/Jujuy        |
| Argentina Standard Time (America/Argentina/La_Rioja)       | America/Argentina/La_Rioja     |
| Argentina Standard Time (America/Argentina/Mendoza)        | America/Argentina/Mendoza      |
| Argentina Standard Time (America/Argentina/Rio_Gallegos)   | America/Argentina/Rio_Gallegos |
| Argentina Standard Time (America/Argentina/Salta)          | America/Argentina/Salta        |
| Argentina Standard Time (America/Argentina/San_Juan)       | America/Argentina/San_Juan     |
| Argentina Standard Time (America/Argentina/San_Luis)       | America/Argentina/San_Luis     |
| Argentina Standard Time (America/Argentina/Tucuman)        | America/Argentina/Tucuman      |
| Argentina Standard Time (America/Argentina/Ushuaia)        | America/Argentina/Ushuaia      |
| Armenia Standard Time (Asia/Yerevan)                       | Asia/Yerevan                   |
| Atlantic Standard Time (America/Anguilla)                  | America/Anguilla               |
| Atlantic Standard Time (America/Antigua)                   | America/Antigua                |
| Atlantic Standard Time (America/Aruba)                     | America/Aruba                  |
| Atlantic Standard Time (America/Barbados)                  | America/Barbados               |
| Atlantic Standard Time (America/Blanc-Sablon)              | America/Blanc-Sablon           |
| Atlantic Standard Time (America/Curacao)                   | America/Curacao                |
| Atlantic Standard Time (America/Dominica)                  | America/Dominica               |
| Atlantic Standard Time (America/Glace_Bay)                 | America/Glace_Bay              |
| Atlantic Standard Time (America/Goose_Bay)                 | America/Goose_Bay              |
| Atlantic Standard Time (America/Grenada)                   | America/Grenada                |
| Atlantic Standard Time (America/Guadeloupe)                | America/Guadeloupe             |
| Atlantic Standard Time (America/Halifax)                   | America/Halifax                |
| Atlantic Standard Time (America/Kralendijk)                | America/Kralendijk             |
| Atlantic Standard Time (America/Lower_Princes)             | America/Lower_Princes          |
| Atlantic Standard Time (America/Marigot)                   | America/Marigot                |
| Atlantic Standard Time (America/Martinique)                | America/Martinique             |
| Atlantic Standard Time (America/Moncton)                   | America/Moncton                |
| Atlantic Standard Time (America/Montserrat)                | America/Montserrat             |
| Atlantic Standard Time (America/Port_of_Spain)             | America/Port_of_Spain          |
| Atlantic Standard Time (America/Puerto_Rico)               | America/Puerto_Rico            |
| Atlantic Standard Time (America/Santo_Domingo)             | America/Santo_Domingo          |
| Atlantic Standard Time (America/St_Barthelemy)             | America/St_Barthelemy          |
| Atlantic Standard Time (America/St_Kitts)                  | America/St_Kitts               |
| Atlantic Standard Time (America/St_Lucia)                  | America/St_Lucia               |
| Atlantic Standard Time (America/St_Thomas)                 | America/St_Thomas              |
| Atlantic Standard Time (America/St_Vincent)                | America/St_Vincent             |
| Atlantic Standard Time (America/Thule)                     | America/Thule                  |
| Atlantic Standard Time (America/Tortola)                   | America/Tortola                |
| Atlantic Standard Time (Atlantic/Bermuda)                  | Atlantic/Bermuda               |
| Australian Central Standard Time (Australia/Adelaide)      | Australia/Adelaide             |
| Australian Central Standard Time (Australia/Broken_Hill)   | Australia/Broken_Hill          |
| Australian Central Standard Time (Australia/Darwin)        | Australia/Darwin               |
| Australian Central Western Standard Time (Australia/Eucla) | Australia/Eucla                |
| Australian Eastern Standard Time (Antarctica/Macquarie)    | Antarctica/Macquarie           |
| Australian Eastern Standard Time (Australia/Brisbane)      | Australia/Brisbane             |
| Australian Eastern Standard Time (Australia/Hobart)        | Australia/Hobart               |
| Australian Eastern Standard Time (Australia/Lindeman)      | Australia/Lindeman             |
| Australian Eastern Standard Time (Australia/Melbourne)     | Australia/Melbourne            |
| Australian Eastern Standard Time (Australia/Sydney)        | Australia/Sydney               |
| Australian Western Standard Time (Australia/Perth)         | Australia/Perth                |
| Azerbaijan Standard Time (Asia/Baku)                       | Asia/Baku                      |
| Azores Standard Time (Atlantic/Azores)                     | Atlantic/Azores                |
| Bangladesh Standard Time (Asia/Dhaka)                      | Asia/Dhaka                     |
| Bhutan Time (Asia/Thimphu)                                 | Asia/Thimphu                   |
| Bolivia Time (America/La_Paz)                              | America/La_Paz                 |
| Brasilia Standard Time (America/Araguaina)                 | America/Araguaina              |
| Brasilia Standard Time (America/Bahia)                     | America/Bahia                  |
| Brasilia Standard Time (America/Belem)                     | America/Belem                  |
| Brasilia Standard Time (America/Fortaleza)                 | America/Fortaleza              |
| Brasilia Standard Time (America/Maceio)                    | America/Maceio                 |
| Brasilia Standard Time (America/Recife)                    | America/Recife                 |
| Brasilia Standard Time (America/Santarem)                  | America/Santarem               |
| Brasilia Standard Time (America/Sao_Paulo)                 | America/Sao_Paulo              |
| Brunei Darussalam Time (Asia/Brunei)                       | Asia/Brunei                    |
| Cape Verde Standard Time (Atlantic/Cape_Verde)             | Atlantic/Cape_Verde            |
| Casey Time (Antarctica/Casey)                              | Antarctica/Casey               |
| Central Africa Time (Africa/Blantyre)                      | Africa/Blantyre                |
| Central Africa Time (Africa/Bujumbura)                     | Africa/Bujumbura               |
| Central Africa Time (Africa/Gaborone)                      | Africa/Gaborone                |
| Central Africa Time (Africa/Harare)                        | Africa/Harare                  |
| Central Africa Time (Africa/Juba)                          | Africa/Juba                    |
| Central Africa Time (Africa/Khartoum)                      | Africa/Khartoum                |
| Central Africa Time (Africa/Kigali)                        | Africa/Kigali                  |
| Central Africa Time (Africa/Lubumbashi)                    | Africa/Lubumbashi              |
| Central Africa Time (Africa/Lusaka)                        | Africa/Lusaka                  |
| Central Africa Time (Africa/Maputo)                        | Africa/Maputo                  |
| Central Africa Time (Africa/Windhoek)                      | Africa/Windhoek                |
| Central European Standard Time (Africa/Algiers)            | Africa/Algiers                 |
| Central European Standard Time (Africa/Ceuta)              | Africa/Ceuta                   |
| Central European Standard Time (Africa/Tunis)              | Africa/Tunis                   |
| Central European Standard Time (Arctic/Longyearbyen)       | Arctic/Longyearbyen            |
| Central European Standard Time (Europe/Amsterdam)          | Europe/Amsterdam               |
| Central European Standard Time (Europe/Andorra)            | Europe/Andorra                 |
| Central European Standard Time (Europe/Belgrade)           | Europe/Belgrade                |
| Central European Standard Time (Europe/Berlin)             | Europe/Berlin                  |
| Central European Standard Time (Europe/Bratislava)         | Europe/Bratislava              |
| Central European Standard Time (Europe/Brussels)           | Europe/Brussels                |
| Central European Standard Time (Europe/Budapest)           | Europe/Budapest                |
| Central European Standard Time (Europe/Busingen)           | Europe/Busingen                |
| Central European Standard Time (Europe/Copenhagen)         | Europe/Copenhagen              |
| Central European Standard Time (Europe/Gibraltar)          | Europe/Gibraltar               |
| Central European Standard Time (Europe/Ljubljana)          | Europe/Ljubljana               |
| Central European Standard Time (Europe/Luxembourg)         | Europe/Luxembourg              |
| Central European Standard Time (Europe/Madrid)             | Europe/Madrid                  |
| Central European Standard Time (Europe/Malta)              | Europe/Malta                   |
| Central European Standard Time (Europe/Monaco)             | Europe/Monaco                  |
| Central European Standard Time (Europe/Oslo)               | Europe/Oslo                    |
| Central European Standard Time (Europe/Paris)              | Europe/Paris                   |
| Central European Standard Time (Europe/Podgorica)          | Europe/Podgorica               |
| Central European Standard Time (Europe/Prague)             | Europe/Prague                  |
| Central European Standard Time (Europe/Rome)               | Europe/Rome                    |
| Central European Standard Time (Europe/San_Marino)         | Europe/San_Marino              |
| Central European Standard Time (Europe/Sarajevo)           | Europe/Sarajevo                |
| Central European Standard Time (Europe/Skopje)             | Europe/Skopje                  |
| Central European Standard Time (Europe/Stockholm)          | Europe/Stockholm               |
| Central European Standard Time (Europe/Tirane)             | Europe/Tirane                  |
| Central European Standard Time (Europe/Vaduz)              | Europe/Vaduz                   |
| Central European Standard Time (Europe/Vatican)            | Europe/Vatican                 |
| Central European Standard Time (Europe/Vienna)             | Europe/Vienna                  |
| Central European Standard Time (Europe/Warsaw)             | Europe/Warsaw                  |
| Central European Standard Time (Europe/Zagreb)             | Europe/Zagreb                  |
| Central European Standard Time (Europe/Zurich)             | Europe/Zurich                  |
| Central Indonesia Time (Asia/Makassar)                     | Asia/Makassar                  |
| Central Standard Time (America/Bahia_Banderas)             | America/Bahia_Banderas         |
| Central Standard Time (America/Belize)                     | America/Belize                 |
| Central Standard Time (America/Chicago)                    | America/Chicago                |
| Central Standard Time (America/Chihuahua)                  | America/Chihuahua              |
| Central Standard Time (America/Costa_Rica)                 | America/Costa_Rica             |
| Central Standard Time (America/El_Salvador)                | America/El_Salvador            |
| Central Standard Time (America/Guatemala)                  | America/Guatemala              |
| Central Standard Time (America/Indiana/Knox)               | America/Indiana/Knox           |
| Central Standard Time (America/Indiana/Tell_City)          | America/Indiana/Tell_City      |
| Central Standard Time (America/Managua)                    | America/Managua                |
| Central Standard Time (America/Matamoros)                  | America/Matamoros              |
| Central Standard Time (America/Menominee)                  | America/Menominee              |
| Central Standard Time (America/Merida)                     | America/Merida                 |
| Central Standard Time (America/Mexico_City)                | America/Mexico_City            |
| Central Standard Time (America/Monterrey)                  | America/Monterrey              |
| Central Standard Time (America/North_Dakota/Beulah)        | America/North_Dakota/Beulah    |
| Central Standard Time (America/North_Dakota/Center)        | America/North_Dakota/Center    |
| Central Standard Time (America/North_Dakota/New_Salem)     | America/North_Dakota/New_Salem |
| Central Standard Time (America/Ojinaga)                    | America/Ojinaga                |
| Central Standard Time (America/Rankin_Inlet)               | America/Rankin_Inlet           |
| Central Standard Time (America/Regina)                     | America/Regina                 |
| Central Standard Time (America/Resolute)                   | America/Resolute               |
| Central Standard Time (America/Swift_Current)              | America/Swift_Current          |
| Central Standard Time (America/Tegucigalpa)                | America/Tegucigalpa            |
| Central Standard Time (America/Winnipeg)                   | America/Winnipeg               |
| Chamorro Standard Time (Pacific/Guam)                      | Pacific/Guam                   |
| Chamorro Standard Time (Pacific/Saipan)                    | Pacific/Saipan                 |
| Chatham Standard Time (Pacific/Chatham)                    | Pacific/Chatham                |
| Chile Standard Time (America/Santiago)                     | America/Santiago               |
| China Standard Time (Asia/Macau)                           | Asia/Macau                     |
| China Standard Time (Asia/Shanghai)                        | Asia/Shanghai                  |
| Christmas Island Time (Indian/Christmas)                   | Indian/Christmas               |
| Chuuk Time (Pacific/Chuuk)                                 | Pacific/Chuuk                  |
| Cocos Islands Time (Indian/Cocos)                          | Indian/Cocos                   |
| Colombia Standard Time (America/Bogota)                    | America/Bogota                 |
| Cook Islands Standard Time (Pacific/Rarotonga)             | Pacific/Rarotonga              |
| Coordinated Universal Time (UTC)                           | UTC                            |
| Cuba Standard Time (America/Havana)                        | America/Havana                 |
| Davis Time (Antarctica/Davis)                              | Antarctica/Davis               |
| Dumont-d’Urville Time (Antarctica/DumontDUrville)          | Antarctica/DumontDUrville      |
| East Africa Time (Africa/Addis_Ababa)                      | Africa/Addis_Ababa             |
| East Africa Time (Africa/Asmara)                           | Africa/Asmara                  |
| East Africa Time (Africa/Dar_es_Salaam)                    | Africa/Dar_es_Salaam           |
| East Africa Time (Africa/Djibouti)                         | Africa/Djibouti                |
| East Africa Time (Africa/Kampala)                          | Africa/Kampala                 |
| East Africa Time (Africa/Mogadishu)                        | Africa/Mogadishu               |
| East Africa Time (Africa/Nairobi)                          | Africa/Nairobi                 |
| East Africa Time (Indian/Antananarivo)                     | Indian/Antananarivo            |
| East Africa Time (Indian/Comoro)                           | Indian/Comoro                  |
| East Africa Time (Indian/Mayotte)                          | Indian/Mayotte                 |
| East Greenland Standard Time (America/Scoresbysund)        | America/Scoresbysund           |
| East Kazakhstan Time (Asia/Almaty)                         | Asia/Almaty                    |
| East Kazakhstan Time (Asia/Qostanay)                       | Asia/Qostanay                  |
| East Timor Time (Asia/Dili)                                | Asia/Dili                      |
| Easter Island Standard Time (Pacific/Easter)               | Pacific/Easter                 |
| Eastern European Standard Time (Africa/Cairo)              | Africa/Cairo                   |
| Eastern European Standard Time (Africa/Tripoli)            | Africa/Tripoli                 |
| Eastern European Standard Time (Asia/Beirut)               | Asia/Beirut                    |
| Eastern European Standard Time (Asia/Gaza)                 | Asia/Gaza                      |
| Eastern European Standard Time (Asia/Hebron)               | Asia/Hebron                    |
| Eastern European Standard Time (Asia/Nicosia)              | Asia/Nicosia                   |
| Eastern European Standard Time (Europe/Athens)             | Europe/Athens                  |
| Eastern European Standard Time (Europe/Bucharest)          | Europe/Bucharest               |
| Eastern European Standard Time (Europe/Chisinau)           | Europe/Chisinau                |
| Eastern European Standard Time (Europe/Helsinki)           | Europe/Helsinki                |
| Eastern European Standard Time (Europe/Kaliningrad)        | Europe/Kaliningrad             |
| Eastern European Standard Time (Europe/Kyiv)               | Europe/Kyiv                    |
| Eastern European Standard Time (Europe/Mariehamn)          | Europe/Mariehamn               |
| Eastern European Standard Time (Europe/Riga)               | Europe/Riga                    |
| Eastern European Standard Time (Europe/Sofia)              | Europe/Sofia                   |
| Eastern European Standard Time (Europe/Tallinn)            | Europe/Tallinn                 |
| Eastern European Standard Time (Europe/Vilnius)            | Europe/Vilnius                 |
| Eastern Indonesia Time (Asia/Jayapura)                     | Asia/Jayapura                  |
| Eastern Standard Time (America/Atikokan)                   | America/Atikokan               |
| Eastern Standard Time (America/Cancun)                     | America/Cancun                 |
| Eastern Standard Time (America/Cayman)                     | America/Cayman                 |
| Eastern Standard Time (America/Detroit)                    | America/Detroit                |
| Eastern Standard Time (America/Grand_Turk)                 | America/Grand_Turk             |
| Eastern Standard Time (America/Indiana/Indianapolis)       | America/Indiana/Indianapolis   |
| Eastern Standard Time (America/Indiana/Marengo)            | America/Indiana/Marengo        |
| Eastern Standard Time (America/Indiana/Petersburg)         | America/Indiana/Petersburg     |
| Eastern Standard Time (America/Indiana/Vevay)              | America/Indiana/Vevay          |
| Eastern Standard Time (America/Indiana/Vincennes)          | America/Indiana/Vincennes      |
| Eastern Standard Time (America/Indiana/Winamac)            | America/Indiana/Winamac        |
| Eastern Standard Time (America/Iqaluit)                    | America/Iqaluit                |
| Eastern Standard Time (America/Jamaica)                    | America/Jamaica                |
| Eastern Standard Time (America/Kentucky/Louisville)        | America/Kentucky/Louisville    |
| Eastern Standard Time (America/Kentucky/Monticello)        | America/Kentucky/Monticello    |
| Eastern Standard Time (America/Nassau)                     | America/Nassau                 |
| Eastern Standard Time (America/New_York)                   | America/New_York               |
| Eastern Standard Time (America/Panama)                     | America/Panama                 |
| Eastern Standard Time (America/Port-au-Prince)             | America/Port-au-Prince         |
| Eastern Standard Time (America/Toronto)                    | America/Toronto                |
| Ecuador Time (America/Guayaquil)                           | America/Guayaquil              |
| Falkland Islands Standard Time (Atlantic/Stanley)          | Atlantic/Stanley               |
| Fernando de Noronha Standard Time (America/Noronha)        | America/Noronha                |
| Fiji Standard Time (Pacific/Fiji)                          | Pacific/Fiji                   |
| French Guiana Time (America/Cayenne)                       | America/Cayenne                |
| French Southern & Antarctic Time (Indian/Kerguelen)        | Indian/Kerguelen               |
| GMT (Africa/Casablanca)                                    | Africa/Casablanca              |
| GMT (Africa/El_Aaiun)                                      | Africa/El_Aaiun                |
| GMT+02:00 (Asia/Famagusta)                                 | Asia/Famagusta                 |
| GMT+03:00 (Asia/Amman)                                     | Asia/Amman                     |
| GMT+03:00 (Asia/Damascus)                                  | Asia/Damascus                  |
| GMT+03:00 (Europe/Istanbul)                                | Europe/Istanbul                |
| GMT+03:00 (Europe/Kirov)                                   | Europe/Kirov                   |
| GMT+04:00 (Europe/Astrakhan)                               | Europe/Astrakhan               |
| GMT+04:00 (Europe/Saratov)                                 | Europe/Saratov                 |
| GMT+04:00 (Europe/Ulyanovsk)                               | Europe/Ulyanovsk               |
| GMT+06:00 (Asia/Urumqi)                                    | Asia/Urumqi                    |
| GMT+07:00 (Asia/Barnaul)                                   | Asia/Barnaul                   |
| GMT+07:00 (Asia/Tomsk)                                     | Asia/Tomsk                     |
| GMT+11:00 (Asia/Srednekolymsk)                             | Asia/Srednekolymsk             |
| GMT+11:00 (Pacific/Bougainville)                           | Pacific/Bougainville           |
| GMT-03:00 (America/Punta_Arenas)                           | America/Punta_Arenas           |
| GMT-03:00 (Antarctica/Palmer)                              | Antarctica/Palmer              |
| Galapagos Time (Pacific/Galapagos)                         | Pacific/Galapagos              |
| Gambier Time (Pacific/Gambier)                             | Pacific/Gambier                |
| Georgia Standard Time (Asia/Tbilisi)                       | Asia/Tbilisi                   |
| Gilbert Islands Time (Pacific/Tarawa)                      | Pacific/Tarawa                 |
| Greenwich Mean Time (Africa/Abidjan)                       | Africa/Abidjan                 |
| Greenwich Mean Time (Africa/Accra)                         | Africa/Accra                   |
| Greenwich Mean Time (Africa/Bamako)                        | Africa/Bamako                  |
| Greenwich Mean Time (Africa/Banjul)                        | Africa/Banjul                  |
| Greenwich Mean Time (Africa/Bissau)                        | Africa/Bissau                  |
| Greenwich Mean Time (Africa/Conakry)                       | Africa/Conakry                 |
| Greenwich Mean Time (Africa/Dakar)                         | Africa/Dakar                   |
| Greenwich Mean Time (Africa/Freetown)                      | Africa/Freetown                |
| Greenwich Mean Time (Africa/Lome)                          | Africa/Lome                    |
| Greenwich Mean Time (Africa/Monrovia)                      | Africa/Monrovia                |
| Greenwich Mean Time (Africa/Nouakchott)                    | Africa/Nouakchott              |
| Greenwich Mean Time (Africa/Ouagadougou)                   | Africa/Ouagadougou             |
| Greenwich Mean Time (Africa/Sao_Tome)                      | Africa/Sao_Tome                |
| Greenwich Mean Time (America/Danmarkshavn)                 | America/Danmarkshavn           |
| Greenwich Mean Time (Antarctica/Troll)                     | Antarctica/Troll               |
| Greenwich Mean Time (Atlantic/Reykjavik)                   | Atlantic/Reykjavik             |
| Greenwich Mean Time (Atlantic/St_Helena)                   | Atlantic/St_Helena             |
| Greenwich Mean Time (Europe/Dublin)                        | Europe/Dublin                  |
| Greenwich Mean Time (Europe/Guernsey)                      | Europe/Guernsey                |
| Greenwich Mean Time (Europe/Isle_of_Man)                   | Europe/Isle_of_Man             |
| Greenwich Mean Time (Europe/Jersey)                        | Europe/Jersey                  |
| Greenwich Mean Time (Europe/London)                        | Europe/London                  |
| Gulf Standard Time (Asia/Dubai)                            | Asia/Dubai                     |
| Gulf Standard Time (Asia/Muscat)                           | Asia/Muscat                    |
| Guyana Time (America/Guyana)                               | America/Guyana                 |
| Hawaii-Aleutian Standard Time (America/Adak)               | America/Adak                   |
| Hawaii-Aleutian Standard Time (Pacific/Honolulu)           | Pacific/Honolulu               |
| Hong Kong Standard Time (Asia/Hong_Kong)                   | Asia/Hong_Kong                 |
| Hovd Standard Time (Asia/Hovd)                             | Asia/Hovd                      |
| India Standard Time (Asia/Colombo)                         | Asia/Colombo                   |
| India Standard Time (Asia/Kolkata)                         | Asia/Kolkata                   |
| Indian Ocean Time (Indian/Chagos)                          | Indian/Chagos                  |
| Indochina Time (Asia/Bangkok)                              | Asia/Bangkok                   |
| Indochina Time (Asia/Ho_Chi_Minh)                          | Asia/Ho_Chi_Minh               |
| Indochina Time (Asia/Phnom_Penh)                           | Asia/Phnom_Penh                |
| Indochina Time (Asia/Vientiane)                            | Asia/Vientiane                 |
| Iran Standard Time (Asia/Tehran)                           | Asia/Tehran                    |
| Irkutsk Standard Time (Asia/Irkutsk)                       | Asia/Irkutsk                   |
| Israel Standard Time (Asia/Jerusalem)                      | Asia/Jerusalem                 |
| Japan Standard Time (Asia/Tokyo)                           | Asia/Tokyo                     |
| Korean Standard Time (Asia/Pyongyang)                      | Asia/Pyongyang                 |
| Korean Standard Time (Asia/Seoul)                          | Asia/Seoul                     |
| Kosrae Time (Pacific/Kosrae)                               | Pacific/Kosrae                 |
| Krasnoyarsk Standard Time (Asia/Krasnoyarsk)               | Asia/Krasnoyarsk               |
| Krasnoyarsk Standard Time (Asia/Novokuznetsk)              | Asia/Novokuznetsk              |
| Kyrgyzstan Time (Asia/Bishkek)                             | Asia/Bishkek                   |
| Line Islands Time (Pacific/Kiritimati)                     | Pacific/Kiritimati             |
| Lord Howe Standard Time (Australia/Lord_Howe)              | Australia/Lord_Howe            |
| Magadan Standard Time (Asia/Magadan)                       | Asia/Magadan                   |
| Malaysia Time (Asia/Kuala_Lumpur)                          | Asia/Kuala_Lumpur              |
| Malaysia Time (Asia/Kuching)                               | Asia/Kuching                   |
| Maldives Time (Indian/Maldives)                            | Indian/Maldives                |
| Marquesas Time (Pacific/Marquesas)                         | Pacific/Marquesas              |
| Marshall Islands Time (Pacific/Kwajalein)                  | Pacific/Kwajalein              |
| Marshall Islands Time (Pacific/Majuro)                     | Pacific/Majuro                 |
| Mauritius Standard Time (Indian/Mauritius)                 | Indian/Mauritius               |
| Mawson Time (Antarctica/Mawson)                            | Antarctica/Mawson              |
| Mexican Pacific Standard Time (America/Hermosillo)         | America/Hermosillo             |
| Mexican Pacific Standard Time (America/Mazatlan)           | America/Mazatlan               |
| Moscow Standard Time (Europe/Minsk)                        | Europe/Minsk                   |
| Moscow Standard Time (Europe/Moscow)                       | Europe/Moscow                  |
| Moscow Standard Time (Europe/Simferopol)                   | Europe/Simferopol              |
| Mountain Standard Time (America/Boise)                     | America/Boise                  |
| Mountain Standard Time (America/Cambridge_Bay)             | America/Cambridge_Bay          |
| Mountain Standard Time (America/Ciudad_Juarez)             | America/Ciudad_Juarez          |
| Mountain Standard Time (America/Creston)                   | America/Creston                |
| Mountain Standard Time (America/Dawson_Creek)              | America/Dawson_Creek           |
| Mountain Standard Time (America/Denver)                    | America/Denver                 |
| Mountain Standard Time (America/Edmonton)                  | America/Edmonton               |
| Mountain Standard Time (America/Fort_Nelson)               | America/Fort_Nelson            |
| Mountain Standard Time (America/Inuvik)                    | America/Inuvik                 |
| Mountain Standard Time (America/Phoenix)                   | America/Phoenix                |
| Myanmar Time (Asia/Yangon)                                 | Asia/Yangon                    |
| Nauru Time (Pacific/Nauru)                                 | Pacific/Nauru                  |
| Nepal Time (Asia/Kathmandu)                                | Asia/Kathmandu                 |
| New Caledonia Standard Time (Pacific/Noumea)               | Pacific/Noumea                 |
| New Zealand Standard Time (Antarctica/McMurdo)             | Antarctica/McMurdo             |
| New Zealand Standard Time (Pacific/Auckland)               | Pacific/Auckland               |
| Newfoundland Standard Time (America/St_Johns)              | America/St_Johns               |
| Niue Time (Pacific/Niue)                                   | Pacific/Niue                   |
| Norfolk Island Standard Time (Pacific/Norfolk)             | Pacific/Norfolk                |
| Novosibirsk Standard Time (Asia/Novosibirsk)               | Asia/Novosibirsk               |
| Omsk Standard Time (Asia/Omsk)                             | Asia/Omsk                      |
| Pacific Standard Time (America/Los_Angeles)                | America/Los_Angeles            |
| Pacific Standard Time (America/Tijuana)                    | America/Tijuana                |
| Pacific Standard Time (America/Vancouver)                  | America/Vancouver              |
| Pakistan Standard Time (Asia/Karachi)                      | Asia/Karachi                   |
| Palau Time (Pacific/Palau)                                 | Pacific/Palau                  |
| Papua New Guinea Time (Pacific/Port_Moresby)               | Pacific/Port_Moresby           |
| Paraguay Standard Time (America/Asuncion)                  | America/Asuncion               |
| Peru Standard Time (America/Lima)                          | America/Lima                   |
| Petropavlovsk-Kamchatski Standard Time (Asia/Kamchatka)    | Asia/Kamchatka                 |
| Philippine Standard Time (Asia/Manila)                     | Asia/Manila                    |
| Phoenix Islands Time (Pacific/Kanton)                      | Pacific/Kanton                 |
| Pitcairn Time (Pacific/Pitcairn)                           | Pacific/Pitcairn               |
| Ponape Time (Pacific/Pohnpei)                              | Pacific/Pohnpei                |
| Rothera Time (Antarctica/Rothera)                          | Antarctica/Rothera             |
| Réunion Time (Indian/Reunion)                              | Indian/Reunion                 |
| Sakhalin Standard Time (Asia/Sakhalin)                     | Asia/Sakhalin                  |
| Samara Standard Time (Europe/Samara)                       | Europe/Samara                  |
| Samoa Standard Time (Pacific/Midway)                       | Pacific/Midway                 |
| Samoa Standard Time (Pacific/Pago_Pago)                    | Pacific/Pago_Pago              |
| Seychelles Time (Indian/Mahe)                              | Indian/Mahe                    |
| Singapore Standard Time (Asia/Singapore)                   | Asia/Singapore                 |
| Solomon Islands Time (Pacific/Guadalcanal)                 | Pacific/Guadalcanal            |
| South Africa Standard Time (Africa/Johannesburg)           | Africa/Johannesburg            |
| South Africa Standard Time (Africa/Maseru)                 | Africa/Maseru                  |
| South Africa Standard Time (Africa/Mbabane)                | Africa/Mbabane                 |
| South Georgia Time (Atlantic/South_Georgia)                | Atlantic/South_Georgia         |
| St. Pierre & Miquelon Standard Time (America/Miquelon)     | America/Miquelon               |
| Suriname Time (America/Paramaribo)                         | America/Paramaribo             |
| Syowa Time (Antarctica/Syowa)                              | Antarctica/Syowa               |
| Tahiti Time (Pacific/Tahiti)                               | Pacific/Tahiti                 |
| Taipei Standard Time (Asia/Taipei)                         | Asia/Taipei                    |
| Tajikistan Time (Asia/Dushanbe)                            | Asia/Dushanbe                  |
| Tokelau Time (Pacific/Fakaofo)                             | Pacific/Fakaofo                |
| Tonga Standard Time (Pacific/Tongatapu)                    | Pacific/Tongatapu              |
| Turkmenistan Standard Time (Asia/Ashgabat)                 | Asia/Ashgabat                  |
| Tuvalu Time (Pacific/Funafuti)                             | Pacific/Funafuti               |
| Ulaanbaatar Standard Time (Asia/Choibalsan)                | Asia/Choibalsan                |
| Ulaanbaatar Standard Time (Asia/Ulaanbaatar)               | Asia/Ulaanbaatar               |
| Uruguay Standard Time (America/Montevideo)                 | America/Montevideo             |
| Uzbekistan Standard Time (Asia/Samarkand)                  | Asia/Samarkand                 |
| Uzbekistan Standard Time (Asia/Tashkent)                   | Asia/Tashkent                  |
| Vanuatu Standard Time (Pacific/Efate)                      | Pacific/Efate                  |
| Venezuela Time (America/Caracas)                           | America/Caracas                |
| Vladivostok Standard Time (Asia/Ust-Nera)                  | Asia/Ust-Nera                  |
| Vladivostok Standard Time (Asia/Vladivostok)               | Asia/Vladivostok               |
| Volgograd Standard Time (Europe/Volgograd)                 | Europe/Volgograd               |
| Vostok Time (Antarctica/Vostok)                            | Antarctica/Vostok              |
| Wake Island Time (Pacific/Wake)                            | Pacific/Wake                   |
| Wallis & Futuna Time (Pacific/Wallis)                      | Pacific/Wallis                 |
| West Africa Standard Time (Africa/Bangui)                  | Africa/Bangui                  |
| West Africa Standard Time (Africa/Brazzaville)             | Africa/Brazzaville             |
| West Africa Standard Time (Africa/Douala)                  | Africa/Douala                  |
| West Africa Standard Time (Africa/Kinshasa)                | Africa/Kinshasa                |
| West Africa Standard Time (Africa/Lagos)                   | Africa/Lagos                   |
| West Africa Standard Time (Africa/Libreville)              | Africa/Libreville              |
| West Africa Standard Time (Africa/Luanda)                  | Africa/Luanda                  |
| West Africa Standard Time (Africa/Malabo)                  | Africa/Malabo                  |
| West Africa Standard Time (Africa/Ndjamena)                | Africa/Ndjamena                |
| West Africa Standard Time (Africa/Niamey)                  | Africa/Niamey                  |
| West Africa Standard Time (Africa/Porto-Novo)              | Africa/Porto-Novo              |
| West Greenland Standard Time (America/Nuuk)                | America/Nuuk                   |
| West Kazakhstan Time (Asia/Aqtau)                          | Asia/Aqtau                     |
| West Kazakhstan Time (Asia/Aqtobe)                         | Asia/Aqtobe                    |
| West Kazakhstan Time (Asia/Atyrau)                         | Asia/Atyrau                    |
| West Kazakhstan Time (Asia/Oral)                           | Asia/Oral                      |
| West Kazakhstan Time (Asia/Qyzylorda)                      | Asia/Qyzylorda                 |
| Western European Standard Time (Atlantic/Canary)           | Atlantic/Canary                |
| Western European Standard Time (Atlantic/Faroe)            | Atlantic/Faroe                 |
| Western European Standard Time (Atlantic/Madeira)          | Atlantic/Madeira               |
| Western European Standard Time (Europe/Lisbon)             | Europe/Lisbon                  |
| Western Indonesia Time (Asia/Jakarta)                      | Asia/Jakarta                   |
| Western Indonesia Time (Asia/Pontianak)                    | Asia/Pontianak                 |
| Yakutsk Standard Time (Asia/Chita)                         | Asia/Chita                     |
| Yakutsk Standard Time (Asia/Khandyga)                      | Asia/Khandyga                  |
| Yakutsk Standard Time (Asia/Yakutsk)                       | Asia/Yakutsk                   |
| Yekaterinburg Standard Time (Asia/Yekaterinburg)           | Asia/Yekaterinburg             |
| Yukon Time (America/Dawson)                                | America/Dawson                 |
| Yukon Time (America/Whitehorse)                            | America/Whitehorse             |
+------------------------------------------------------------+--------------------------------+
</details>

##### Redis

Confirm that Redis is set up correctly:

```bash
docker-compose exec redis redis-cli monitor
```

You should see an output similar to
[experienceleague.adobe.com](https://experienceleague.adobe.com/en/docs/commerce-operations/configuration-guide/cache/redis/redis-pg-cache) (see Verify Redis connection)

##### Health Monitoring & Auto-healing

This setup includes comprehensive health monitoring and automatic healing capabilities:

**Health Checks**: All services have health checks configured:

- **PHP**: Monitors PHP-FPM process status
- **Database**: Checks MySQL connectivity and initialization
- **Redis**: Verifies Redis server response
- **Nginx**: Tests HTTP response on port 8080
- **Caddy**: Validates port connectivity on 80 and 443
- **Varnish**: Depends on healthy web service

**Auto-healing**: The `autoheal` service automatically restarts any container that fails its health check, ensuring high availability and reducing manual intervention.

You can monitor container health status with:

```bash
docker-compose ps
```

Healthy containers show "healthy" status, while problematic ones show "unhealthy".

##### Database

- `MYSQL_ROOT_PASSWORD` - Optional, Required on first run
- `MYSQL_DATABASE` - Optional, Required on first run
- `MYSQL_USER` - Optional, Required on first run
- `MYSQL_PASSWORD` - Optional, Required on first run

##### Web

- `BACKEND_HOST` - Required - Must be set to the php host
- `SERVER_NAME` - Required - Server name must be identical to the name of the container

##### SSL Proxy

- `BACKEND_HOST` - Required - Must be set to the varnish host
- `SERVER_NAME` - Required - The server name that you'd like to type in the browser

### PHP Extension Management

PHP extensions required by Magento are automatically installed during Docker build based on `src/composer.json` requirements. The build process:

1. Parses composer.json for `ext-*` entries
2. Maps extensions to Alpine Linux packages
3. Installs extensions with `docker-php-ext-install`
4. Validates all extensions loaded successfully

When upgrading Magento versions, extension requirements are automatically synchronized. No manual Dockerfile updates needed.

See [docs/PHP_EXTENSIONS.md](docs/PHP_EXTENSIONS.md) for details.

## Renovate

The dependencies within this repository are automatically updated by Renovate. To ensure compatibility with dependencies like Redis, MariaDB, Varnish, etc., I wrote a little script (`update-dependency-version.sh`) that gets the latest compatibility list from https://experienceleague.adobe.com/en/docs/commerce-operations/installation-guide/system-requirements and passes it to the Renovate configuration `renovate.json`. This should keep the repository up to date while still maintaining compatibility.

## Backup MySQL database

Linux and Mac:

```bash
docker-compose exec db /usr/bin/mysqldump -u magento2 --password=magento2 magento2 > backup.sql
```

Replace `magento2` for user, password and database with whatever you've set in the docker-compose file.

## From development to production environment

### This is still WIP!

This repository implements the [recommended deployment](https://devdocs.magento.com/guides/v2.2/config-guide/deployment/pipeline/technical-details.html) process from Magento with the help of Docker containers.
The process is as follows:

1. Dump your configuration on the development machine:

```bash
docker-compose exec php bin/magento app:config:dump scopes themes
```

3. Build the php container for production

```bash
docker build -f php/Dockerfile -t magento2-php-prod .
```

4. Build the nginx container for production

```bash
docker build -f nginx/Dockerfile -t magento2-nginx-prod .
```

Note: The nginx Dockerfile refers to `magento2-php-prod` to copy some files. So make sure that you name the `php` image `magento2-php-prod`. 5. Move the `php` and `nginx` image to your production environment 6. Run the following on your production machine

```bash
docker-compose up -f prod.docker-compose.yml
```

## Q&A

- How do I find the admin URI?

```bash
docker-compose exec php php bin/magento info:adminuri
```

- The following error is thrown when php container for production is build

```bash
+ php bin/magento setup:static-content:deploy -f

Deploy using quick strategy

  [DomainException]
  Default website is not defined
```

_Answer:_ Make sure you have run `app:config:dump scopes themes` (example: `docker-compose exec php bin/magento app:config:dump scopes themes`).

## Hyvä Theme Support

This setup includes Node.js in the PHP container to support frontend build tools like the [Hyvä theme](https://hyva.io)'s Tailwind CSS compiler.

### Installing Hyvä

Hyvä requires a free packagist.com key. Register at [hyva.io](https://hyva.io) and create a key from your account dashboard.

```bash
# Add your Hyvä packagist key
docker compose run --rm composer config --auth http-basic.hyva-themes.repo.packagist.com token yourLicenseKey
docker compose run --rm composer config repositories.private-packagist composer https://hyva-themes.repo.packagist.com/yourProjectName/

# Install the theme
docker compose run --rm composer require hyva-themes/magento2-default-theme
docker compose exec php bin/magento setup:upgrade
```

Then activate the `hyva/default` theme in **Content → Design → Configuration**.

### Building Tailwind CSS

A `tailwind` helper script is included that automatically detects all installed themes with a Tailwind setup and runs `npm ci` + the appropriate build command.

During development, start the watcher (auto-rebuilds on file changes):

```bash
docker compose exec php tailwind watch
```

For a one-time production build:

```bash
docker compose exec php tailwind build
```

The script scans `app/design/frontend/` and `vendor/hyva-themes/` for themes containing a `web/tailwind/package.json`.

### Additional Hyvä Setup

After installation, add these environment variables to your `docker-compose.override.yml` under the `php` service to apply the recommended Hyvä configuration:

```yaml
php:
  environment:
    # Disable legacy Magento captcha (use ReCaptcha instead)
    - CONFIG__DEFAULT__CUSTOMER__CAPTCHA__ENABLE=0
    # Disable built-in minification/bundling (not needed with Hyvä)
    - CONFIG__DEFAULT__DEV__JS__MERGE_FILES=0
    - CONFIG__DEFAULT__DEV__JS__ENABLE_JS_BUNDLING=0
    - CONFIG__DEFAULT__DEV__JS__MINIFY_FILES=0
    - CONFIG__DEFAULT__DEV__JS__MOVE_SCRIPT_TO_BOTTOM=0
    - CONFIG__DEFAULT__DEV__CSS__MERGE_CSS_FILES=0
    - CONFIG__DEFAULT__DEV__CSS__MINIFY_FILES=0
    - CONFIG__DEFAULT__DEV__TEMPLATE__MINIFY_HTML=0
```

See the [Hyvä documentation](https://docs.hyva.io/hyva-themes/getting-started/index.html) for the full setup guide.

## Todos

- Add Let's encrypt example for production
- Add a periodic MySQL backup

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
Magento 2 is licensed under their [official license](https://github.com/magento/magento2/blob/2.3-develop/LICENSE.txt).
