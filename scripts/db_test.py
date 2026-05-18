import mysql.connector, os
cfg = {
    'host': os.environ.get('DB_HOST','localhost'),
    'port': int(os.environ.get('DB_PORT',3306)),
    'user': os.environ.get('DB_USER','root'),
    'password': os.environ.get('DB_PASSWORD',''),
    'database': os.environ.get('DB_NAME','neet_app'),
}
print('Using', cfg)
try:
    cn = mysql.connector.connect(**cfg, connection_timeout=10)
    cur = cn.cursor()
    cur.execute('SELECT 1')
    print('OK', cur.fetchone())
    cur.close(); cn.close()
except Exception as e:
    print('EXC', e)
