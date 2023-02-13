# Deploy CMS and create infrastructure as code
---
## Состав и версии компонент дистрибутива
### Логирование
- ElasticSearch 8.1.1
- Kibana 8.1.1
- Fluentd 3.6.0

### Метрики
- Prometheus 2.1.0
- Node-exporter 1.5.0
- Grafana 9.3.6

### Сборка CI/CD
- GitLab 15.2.4-ee
- Shell runner
- PHP linter

### Сборка CI/CD
- Nginx 1.23.3
- PHP 8.1
- Postgres 13
- Composer 2.3.0
- October CMS 3.*

### Параметры разворачиваемого сервера
- OS: Ubuntu 18.04
- Количество ядер процессора: 2
- Платформа: Intel Ice Lake
- RAM: 6GB
- HDD: 30GB

### Схема размещения компонент
![Схема размещения компонент](https://github.com/vbif87vbif/sample_project_with_iac_cicd/blob/main/docs/component_schema.png?raw=true "Схема размещения компонент").

### Схема линковки web-адресов
![Схема линковки web-адресов](https://github.com/vbif87vbif/sample_project_with_iac_cicd/blob/main/docs/web.png?raw=true "Схема линковки web-адресов").