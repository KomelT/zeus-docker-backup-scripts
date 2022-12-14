#!/usr/bin/bash

# backup name
name="passbolt"

date=$(date +"%y-%m-%d_%H:%M:%S")

# create necessary folders
tmp_folder="/appdata/tmp/${name}"
mkdir -p "${tmp_folder}/${date}"

# set-up logs
mkdir -p "${tmp_folder}/logs"
echo "------ ${date} ------" >> "${tmp_folder}/${date}/log_${date}.log"
echo "" >> "${tmp_folder}/${date}/log_${date}.log"

err=false

# ------------------------------- BACKUP START
# backup db to .sql
docker exec -i passbolt-db-1 mysqldump -u passbolt --password="${PASSB_DB_PASSWORD}" passbolt > "${tmp_folder}/${date}/passbolt-sqlbkp_${date}.sql" 2>> "${tmp_folder}/${date}/log_${date}.log"
if [[ $? -ne 0 ]]; then
    err=true
fi


# backup serverkey_private.asc
docker cp passbolt-app-1:/etc/passbolt/gpg/serverkey_private.asc "${tmp_folder}/${date}/passbolt-srvkey-privatebkp_${date}.asc"
if [[ $? -ne 0 ]]; then
    err=true
fi


# backup serverkey.asc
docker cp passbolt-app-1:/etc/passbolt/gpg/serverkey.asc "${tmp_folder}/${date}/passbolt-srvkeybkp_${date}.asc"
if [[ $? -ne 0 ]]; then
    err=true
fi


# backup nginx.conf
cp "/etc/nginx/conf.d/dev.komelt.passbolt.conf" "${tmp_folder}/${date}/nginx-confbkp_${date}.conf" 2>> "${tmp_folder}/${date}/log_${date}.log"
if [[ $? -ne 0 ]]; then
    err=true
fi


# backup serverkey.asc
docker cp passbolt-app-1:/usr/share/php/passbolt/plugins/PassboltCe/WebInstaller/templates/Config/passbolt.php "${tmp_folder}/${date}/passbolt-confbkp_${date}.php"
if [[ $? -ne 0 ]]; then
    err=true
fi
# ------------------------------- BACKUP END

# ------------------------------- SYNC FILES START

# Remove directories that are older than 30 days
cd "${tmp_folder}"

find "${tmp_folder}"/* -mtime +30 -maxdepth 0 -exec basename {} \; | xargs rm -r {}

# Backblaze b2 authorize
b2 authorize-account $BACKB_KEY_ID $BACKB_APP_KEY 2>> "${tmp_folder}/${date}/log_${date}.log"
if [[ $? -ne 0 ]]; then
    err=true
fi

# Sync local cirectory with b2 bucket
b2 sync --delete --compareVersions none "${tmp_folder}" "b2://zeus-docker-backup/${name}/" 2>> "${tmp_folder}/${date}/log_${date}.log"
if [[ $? -ne 0 ]]; then
    err=true
fi

# ------------------------------- SYNC FILES END


echo "" >> "${tmp_folder}/${date}/log_${date}.log"
echo "" >> "${tmp_folder}/${date}/log_${date}.log"

if [[ $err == "true" ]]; then
    exit 1
fi