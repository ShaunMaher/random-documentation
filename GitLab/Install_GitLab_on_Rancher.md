# Install GitLab on Rancher
## Prerequsites
* PostgreSQL service
  * HA on Rancher?
    * Is Longhorn suitable storage for a DB?
    * I'm thinking a three node PostgreSQL cluster on "local-path" storage.
      This storage is not HA or replicated but I'm hoping that PostgreSQL/
      Patroni can take care of that part.
    * If I use a TimescaleDB deployment of PostgreSQL HA then I can re-use the
      same cluster for Zabbix
  * Single node on Rancher?
    * Same questions regarding storage
* Object Storage
  * Minio?
    * I've used Minio and it has ... quirks.  Alternatives?
* Redis
  * Three node HA should be simple enough (I hope)

