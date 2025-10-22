#!/bin/bash
set -e

# Log all output to a file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting SonarQube installation..."

# Step 1: Update system and install dependencies
echo "Installing system dependencies..."
dnf update -y
dnf install -y unzip wget git java-17-amazon-corretto postgresql15 postgresql15-server

# Verify Java installation
java -version

# Step 2: Setup PostgreSQL Database
echo "Setting up PostgreSQL..."
/usr/bin/postgresql-setup --initdb
systemctl enable --now postgresql

# Wait for PostgreSQL to be ready
sleep 10

# Create database and user
sudo -i -u postgres psql <<EOF
CREATE DATABASE sonarqube;
CREATE USER sonar WITH ENCRYPTED PASSWORD '${db_password}';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
ALTER DATABASE sonarqube OWNER TO sonar;
EOF

# Configure PostgreSQL to allow password authentication
cat >> /var/lib/pgsql/data/pg_hba.conf <<EOF
host    sonarqube       sonar           127.0.0.1/32            md5
EOF

# Restart PostgreSQL to apply changes
systemctl restart postgresql

# Step 3: Install SonarQube
echo "Installing SonarQube..."
cd /opt
wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.6.0.92116.zip
unzip -q sonarqube-10.6.0.92116.zip
mv sonarqube-10.6.0.92116 sonarqube
rm sonarqube-10.6.0.92116.zip

# Step 4: Configure SonarQube
echo "Configuring SonarQube..."
cat >> /opt/sonarqube/conf/sonar.properties <<EOF

# Database configuration
sonar.jdbc.username=sonar
sonar.jdbc.password=${db_password}
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube

# Web server configuration
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF

# Step 5: Create system user and set permissions
echo "Creating sonar user and setting permissions..."
useradd sonar
chown -R sonar:sonar /opt/sonarqube

# Set system limits for SonarQube
cat >> /etc/security/limits.conf <<EOF
sonar   -   nofile   65536
sonar   -   nproc    4096
EOF

# Set kernel parameters
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf

# Step 6: Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/sonarqube.service <<EOF
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
EOF

# Step 7: Start and enable SonarQube service
echo "Starting SonarQube service..."
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "SonarQube installation complete!"
echo "It may take 2-3 minutes for SonarQube to fully start up."
echo "Access SonarQube at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "Default credentials - Username: admin, Password: admin"
