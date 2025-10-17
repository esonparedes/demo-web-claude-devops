Let’s set up **SonarQube (Community Edition — Free)** on an **Amazon Linux 2023** EC2 instance (self-hosted).

We’ll use **PostgreSQL** as the backend DB and **systemd** for service management.
Below is the **step-by-step guide**, which you can copy and paste line-by-line.

---

## 🧱 Prerequisites

✅ EC2 instance with:

* Amazon Linux 2023
* Minimum 2 vCPUs, 4GB RAM (8GB+ recommended for large projects)
* Port `9000` open in Security Group

✅ Root or `sudo` privileges

---

## 🧩 Step 1: Update System and Install Dependencies

```bash
sudo dnf update -y
sudo dnf install -y unzip wget git java-17-amazon-corretto postgresql15 postgresql15-server
```

Verify Java:

```bash
java -version
```

Expected output (similar):

```
openjdk version "17.x" 202x-xx-xx LTS
```

---

## 🗄 Step 2: Setup PostgreSQL Database

Initialize and start the DB:

```bash
sudo /usr/bin/postgresql-setup --initdb
sudo systemctl enable --now postgresql
```

Switch to the postgres user and create DB + user:

```bash
sudo -i -u postgres
psql
```

Run these SQL commands:

```sql
CREATE DATABASE sonarqube;
CREATE USER sonar WITH ENCRYPTED PASSWORD 'StrongPasswordHere';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
\q
exit
```

---

## 🧰 Step 3: Install SonarQube

Get the latest LTS version (Community Edition):

```bash
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.6.0.92116.zip
sudo unzip sonarqube-10.6.0.92116.zip
sudo mv sonarqube-10.6.0.92116 sonarqube
sudo chown -R ec2-user:ec2-user sonarqube
```

---

## ⚙️ Step 4: Configure SonarQube to use PostgreSQL

Edit the config file:

```bash
sudo nano /opt/sonarqube/conf/sonar.properties
```

Uncomment and modify these lines:

```properties
sonar.jdbc.username=sonar
sonar.jdbc.password=StrongPasswordHere
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube

# Optional but recommended:
sonar.web.host=0.0.0.0
sonar.web.port=9000
```

Save and exit.

---

## 🚀 Step 5: Create a System User and Service

Create a dedicated user:

```bash
sudo useradd sonar
sudo chown -R sonar:sonar /opt/sonarqube
```

Create a **systemd service file**:

```bash
sudo nano /etc/systemd/system/sonarqube.service
```

Paste:

```ini
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
```

Save and exit.

---

## 🏁 Step 6: Start and Enable the Service

Reload systemd and start SonarQube:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sonarqube
```

Check status:

```bash
sudo systemctl status sonarqube
```

---

## 🌐 Step 7: Access SonarQube Dashboard

Open your browser and go to:

```
http://<EC2_PUBLIC_IP>:9000
```

Default credentials:

```
Username: admin
Password: admin
```

You’ll be prompted to change the password on first login.

---

## 🧮 (Optional) Step 8: Reverse Proxy via Nginx

If you want to serve over port 80:

```bash
sudo dnf install -y nginx
sudo systemctl enable --now nginx
```

Edit config:

```bash
sudo nano /etc/nginx/conf.d/sonarqube.conf
```

Add:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Restart nginx:

```bash
sudo systemctl restart nginx
```

Then access:

```
http://<EC2_PUBLIC_IP>
```

---

## ✅ Verification

To confirm SonarQube is working:

```bash
curl -I http://localhost:9000
```

You should see `HTTP/1.1 200 OK` after a minute or two (SonarQube takes time to start up).

---

Would you like me to create a **Terraform module** that provisions this EC2 + setup script automatically (for faster redeployments)?
