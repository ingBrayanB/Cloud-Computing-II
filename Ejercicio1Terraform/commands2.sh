#!/bin/bash
# Actualizamos el sistema actual e instalamos los requisitos
sudo yum update -y

# Instalamos Docker en la instancia
sudo yum install docker -y

# Iniciamos Docker dentro de la instancia
sudo systemctl start docker 

# Agregamos el usuario ec2-user al grupo docker para ejecutar sin sudo
sudo usermod -a -G docker ec2-user

# Habilitamos Docker para iniciar con el sistema
sudo systemctl enable docker

# Descargamos e iniciamos el contenedor de Nginx
sudo docker run -d -p 80:80 --name nginx-container nginx

sleep 10

sudo docker exec nginx-container sed -i 's/<h1>Welcome to nginx!<\/h1>/<h1>Hola, mundo Brayan Badillo Instancia 2!<\/h1>/g' /usr/share/nginx/html/index.html

sudo docker exec -it nginx-container cat /usr/share/nginx/html/index.html