#!/usr/bin/env bash
# Renders public/ into site/ (served by nginx for the home page and /privacy), filling in the
# privacy contact from PRIVACY_CONTACT_EMAIL in .env. The address lives only on the server: this
# repository is public. Run from the repository root (deploy.sh does this).
set -euo pipefail

email=""
if [ -f .env ]; then
  email=$(grep -E '^PRIVACY_CONTACT_EMAIL=' .env | tail -n 1 | cut -d= -f2- | tr -d "\"' \r" || true)
fi

if [[ "$email" =~ ^[^[:space:]@\<\>\&\"\'\\/]+@[^[:space:]@\<\>\&\"\'\\/]+\.[^[:space:]@\<\>\&\"\'\\/]+$ ]]; then
  contact_id="Pertanyaan dan permintaan soal data Anda: <a href=\"mailto:${email}\">${email}</a>"
  contact_en="Questions and requests about your data: <a href=\"mailto:${email}\">${email}</a>"
else
  [ -z "$email" ] || echo "PRIVACY_CONTACT_EMAIL is not a valid address; leaving the contact unset" >&2
  contact_id="Kontak untuk pertanyaan soal data Anda belum diatur."
  contact_en="The contact for questions about your data has not been set up yet."
fi

rm -rf site
mkdir -p site
cp public/index.html public/style.css site/
sed -e "s|@@CONTACT_ID@@|${contact_id}|" -e "s|@@CONTACT_EN@@|${contact_en}|" \
  public/privacy.html > site/privacy.html
echo "Rendered site/"
