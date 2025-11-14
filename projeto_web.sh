#!/bin/bash
# ------------------------------------------------------------
# Script de Automação: Instalação de Servidor Web Apache
# Autor: [Seu Nome]
# Descrição:
#   - Interage com o usuário pedindo confirmação
#   - Instala automaticamente o Apache
#   - Baixa um template HTML da internet
#   - Publica o template como página inicial do servidor
# ------------------------------------------------------------

# Função para exibir mensagens formatadas
function info() {
    echo -e "\n[INFO] $1\n"
}

# 1. Confirmação do usuário
echo "Este script irá instalar e configurar um servidor WEB (Apache)."
read -p "Deseja continuar? (s/n): " resposta

if [[ "$resposta" != "s" && "$resposta" != "S" ]]; then
    echo "Instalação cancelada pelo usuário."
    exit 1
fi

# 2. Atualizando pacotes do sistema
info "Atualizando lista de pacotes..."
sudo apt update -y

# 3. Instalando o Apache
info "Instalando o servidor Apache..."
sudo apt install apache2 -y

# 4. Habilitando e iniciando o serviço
info "Habilitando e iniciando o serviço Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

# 5. Baixando template HTML da internet
info "Baixando template HTML..."
# Exemplo: usando um template simples do GitHub
TEMPLATE_URL="https://raw.githubusercontent.com/BlackrockDigital/startbootstrap-creative/master/index.html"
wget -O /tmp/index.html $TEMPLATE_URL

# 6. Publicando o template no diretório padrão do Apache
info "Publicando template no diretório padrão do Apache..."
sudo cp /tmp/index.html /var/www/html/index.html

# 7. Ajustando permissões
info "Ajustando permissões..."
sudo chown www-data:www-data /var/www/html/index.html
sudo chmod 644 /var/www/html/index.html

# 8. Finalização
info "Instalação concluída!"
echo "Abra o navegador e acesse: http://localhost ou http://SEU_IP"
