#!/bin/bash
# O binario do bore nao fica mais no git. Instale seguindo o README
# (secao "Instalar o bore"), conferindo o SHA-256.
if [ ! -x ./bore ]; then
  echo "ERRO: ./bore nao encontrado. Veja a secao 'Instalar o bore' do README." >&2
  exit 1
fi
echo "Iniciando túnel Bore..."
./bore local 25565 --to bore.pub &
sleep 2
echo "Iniciando servidor Minecraft..."
./start.sh &
echo "Ambos iniciados em background."
