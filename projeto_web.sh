#!/bin/bash

# =============================================================================
# Script de Automação - Deploy de Site (Debian/Ubuntu)
#
# Objetivo:
#   - Instalar e configurar um servidor web Apache
#   - Definir IP fixo/estático
#   - Ocultar versão do Apache nos cabeçalhos HTTP
#   - Publicar um template HTML baixado da internet
#   - Reiniciar o servidor após configuração
# =============================================================================

# --- 1. Verificação de superusuário ---
# Verifica se o script está sendo executado como root (EUID = 0).
# Caso contrário, exibe aviso e encerra.
if [[ $EUID -ne 0 ]]; then
   echo "Atenção: Este script precisa ser executado como root."
   echo "Exemplo: sudo ./deploy_site.sh"
   exit 1
fi

# --- 2. Interação com o usuário ---
# Exibe informações iniciais e pede confirmação para continuar.
echo "===================================================="
echo " Script de Deploy Automático de Servidor Web Apache "
echo "===================================================="
echo "Este processo irá instalar o Apache, configurar IP fixo e publicar um site."
read -p "Deseja continuar? [s/n]: " decisao

# Se o usuário responder diferente de 's' ou 'S', o script é cancelado.
if [[ "$decisao" != "s" && "$decisao" != "S" ]]; then
    echo "Execução cancelada pelo usuário."
    exit 0
fi

# --- 3. Atualização e instalação de pacotes ---
# Atualiza lista de pacotes e instala Apache, wget, unzip e net-tools.
echo "Atualizando lista de pacotes..."
apt update -y

echo "Instalando pacotes necessários (apache2, wget, unzip)..."
apt install -y apache2 wget unzip net-tools

# --- 4. Configuração do serviço Apache ---
# Habilita o Apache para iniciar junto com o sistema e inicia o serviço imediatamente.
echo "Ativando e iniciando o serviço apache2..."
systemctl enable apache2
systemctl start apache2

# --- 5. Ocultar versão do Apache nos cabeçalhos HTTP ---
# Adiciona diretivas de segurança no arquivo de configuração para não exibir versão do Apache.
# Usa 'grep' para evitar duplicação das linhas.
echo "Configurando Apache para ocultar versão nos cabeçalhos..."
conf_file="/etc/apache2/conf-available/security.conf"
grep -q "ServerTokens Prod" $conf_file || echo "ServerTokens Prod" >> $conf_file
grep -q "ServerSignature Off" $conf_file || echo "ServerSignature Off" >> $conf_file
a2enconf security
systemctl restart apache2

# --- 6. Configuração de IP fixo ---
# Detecta interface de rede padrão, IP atual e gateway.
# Cria arquivo de configuração Netplan para definir IP fixo.
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
# Define diretório web e URLs do template (principal e fallback).
# Baixa o template, verifica integridade, extrai e publica no Apache.
diretorio_web="/var/www/html"
url_arquivo_primary="https://templatemo.com/tm-zip-files-2020/templatemo_600_prism_flux.zip"
url_arquivo_fallback="https://github.com/startbootstrap/startbootstrap-clean-blog/archive/refs/heads/master.zip"
arquivo_zip="/tmp/site.zip"

echo "Limpando conteúdo atual de ${diretorio_web}..."
rm -rf ${diretorio_web}/*

echo "Baixando template primário de ${url_arquivo_primary}..."
if ! wget -q -O "${arquivo_zip}" "${url_arquivo_primary}"; then
  echo "Aviso: Falha ao baixar do templatemo. Tentando fallback..."
  if ! wget -q -O "${arquivo_zip}" "${url_arquivo_fallback}"; then
    echo "Erro: Falha ao baixar o template em ambas as URLs."
    exit 1
  fi
fi

echo "Verificando integridade do arquivo ZIP..."
if ! unzip -t "${arquivo_zip}" > /dev/null 2>&1; then
  echo "Erro: Arquivo ZIP corrompido."
  rm -f "${arquivo_zip}"
  exit 1
fi

echo "Extraindo template em ${diretorio_web}..."
unzip -q "${arquivo_zip}" -d "${diretorio_web}/"

# Detecta automaticamente a pasta raiz criada pela extração.
pasta_raiz=$(find "${diretorio_web}" -maxdepth 1 -mindepth 1 -type d | head -n 1)
if [[ -z "${pasta_raiz}" ]]; then
  echo "Erro: Pasta raiz do template não encontrada após extração."
  rm -f "${arquivo_zip}"
  exit 1
fi

echo "Movendo arquivos do template para ${diretorio_web}..."
shopt -s dotglob
mv "${pasta_raiz}"/* "${diretorio_web}/"
shopt -u dotglob
rmdir "${pasta_raiz}" 2>/dev/null || true

# Ajusta permissões para que o Apache consiga servir os arquivos.
echo "Ajustando permissões e proprietário..."
chown -R www-data:www-data "${diretorio_web}"
chmod -R 755 "${diretorio_web}"

rm -f "${arquivo_zip}"
echo "Template publicado com sucesso."

# --- 8. Exibir IP local ---
# Captura IP da máquina para exibir ao usuário.
ip_local=$(hostname -I | awk '{print $1}')

# --- 9. Conclusão ---
# Mensagem final informando sucesso e instruções de acesso.
echo "===================================================="
echo "--- Deploy concluído com sucesso! ---"
echo "O Apache está rodando e o site foi publicado."
echo "Acesse pelo navegador: http://localhost ou http://$ip_local"
echo "O servidor será reiniciado para aplicar todas as configurações."
echo "===================================================="

# --- 10. Reinício do servidor ---
# Reinicia o servidor para aplicar todas as configurações.
reboot


