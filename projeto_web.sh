#!/bin/bash

# =============================================================================
# Script de Automação - Deploy de Site (Debian/Ubuntu)
#
# Objetivo: Instalar e configurar um servidor web Apache com um
#           template HTML baixado da internet.
# =============================================================================

# --- 1. Verificação de superusuário ---
if [[ $EUID -ne 0 ]]; then
   echo "Atenção: Este script precisa ser executado como root."
   echo "Exemplo: sudo ./deploy_site.sh"
   exit 1
fi

# --- 2. Interação com o usuário ---
echo "===================================================="
echo " Script de Deploy Automático de Servidor Web Apache "
echo "===================================================="
echo "Este processo irá instalar o Apache, configurar IP fixo e publicar um site."
read -p "Deseja continuar? [s/n]: " decisao

if [[ "$decisao" != "s" && "$decisao" != "S" ]]; then
    echo "Execução cancelada pelo usuário."
    exit 0
fi

# --- 3. Atualização e instalação de pacotes ---
echo "Atualizando lista de pacotes..."
apt update -y

echo "Instalando pacotes necessários (apache2, wget, unzip)..."
apt install -y apache2 wget unzip

# --- 4. Configuração do serviço Apache ---
echo "Ativando e iniciando o serviço apache2..."
systemctl enable apache2
systemctl start apache2

# --- 5. Ocultar versão do Apache nos cabeçalhos HTTP ---
echo "Configurando Apache para ocultar versão nos cabeçalhos..."
echo "ServerTokens Prod" >> /etc/apache2/conf-available/security.conf
echo "ServerSignature Off" >> /etc/apache2/conf-available/security.conf
a2enconf security
systemctl restart apache2

# --- 6. Configuração de IP fixo ---
echo "Configurando IP fixo..."
interface=$(ip route | grep default | awk '{print $5}')
ip_atual=$(ip -4 addr show $interface | grep inet | awk '{print $2}' | cut -d/ -f1)
gateway=$(ip route | grep default | awk '{print $3}')
dns="8.8.8.8"

cat > /etc/netplan/01-static-ip.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses: [$ip_atual/24]
      gateway4: $gateway
      nameservers:
        addresses: [$dns]
EOF

echo "Aplicando nova configuração de rede..."
netplan apply

# --- 7. Download e publicação do template ---
diretorio_web="/var/www/html"
url_arquivo="https://templatemo.com/tm-zip-files-2020/templatemo_600_prism_flux.zip"
arquivo_zip="/tmp/site.zip"
pasta_interna="templatemo_600_prism_flux"

echo "Baixando template de $url_arquivo..."
wget -O $arquivo_zip $url_arquivo

if [ $? -ne 0 ]; then
    echo "Erro: Falha ao baixar o template."
    exit 1
fi

echo "Publicando site em $diretorio_web..."
rm -rf ${diretorio_web}/*
unzip $arquivo_zip -d $diretorio_web/

if [ ! -d "${diretorio_web}/${pasta_interna}" ]; then
    echo "Erro: Pasta do template não encontrada após extração."
    exit 1
fi

mv ${diretorio_web}/${pasta_interna}/* ${diretorio_web}/
rmdir ${diretorio_web}/${pasta_interna}
rm $arquivo_zip

# --- 8. Exibir IP local ---
ip_local=$(hostname -I | awk '{print $1}')

# --- 9. Conclusão ---
echo "===================================================="
echo "--- Deploy concluído com sucesso! ---"
echo "O Apache está rodando e o site foi publicado."
echo "Acesse pelo navegador: http://localhost ou http://$ip_local"
echo "O servidor será reiniciado para aplicar todas as configurações."
echo "===================================================="

# --- 10. Reinício do servidor ---
reboot

