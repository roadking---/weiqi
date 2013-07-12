xcopy views ..\node\views\ /E /Y
xcopy public ..\node\public\ /E /Y
copy package.json ..\node\
coffee -c -o ../node .