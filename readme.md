# Explicación de las Plantillas CloudFormation y Configuración de Redirecciones S3

## 1. Plantillas CloudFormation

### template1.yaml
Esta plantilla crea la infraestructura base necesaria para la PoC:

- **VPC**: Red privada para aislar recursos.
- **Subnet Pública**: Permite acceso a Internet.
- **Internet Gateway y rutas**: Habilita la conectividad externa.
- **Security Group**: Permite tráfico HTTPS (puerto 443).
- **EC2 con Apache**: Instancia con Apache configurado para servir contenido y habilitar HTTPS con un certificado autofirmado.
- **S3 Bucket**: Bucket vacío que se usará para redirecciones.
- **Outputs**: Exporta el DNS público del EC2 y la URL del sitio web S3 para ser usados en otras plantillas.

[Ver template1.yaml](template1.yaml)

Puedes crear el stack desde la consola de AWS o ejecutando el siguiente comando:

```
aws cloudformation create-stack --stack-name create-cloudfront-origins --template-body file://template1.yaml --parameters ParameterKey=ProjectName,ParameterValue=POC-S3RedirecttoHost
```

---

### template2.yaml
Esta plantilla crea los servicios de redirección y distribución:

- **Certificado ACM**: Para el dominio personalizado.
- **CloudFront Distribution**: Distribución con dos orígenes (EC2 y S3), comportamientos personalizados para redirigir ciertas rutas al S3.
- **Behaviors**: Redirige `/About.html`, `/contact.html` y `/empresa/index.html` al origen S3, el resto va al EC2.
- **Route 53 Record**: Crea un registro tipo A apuntando al CloudFront para el dominio.

[Ver template2.yaml](template2.yaml)

Para obtener el valor de `HostedZoneId` necesario para el parámetro `HostedZoneId`, ejecuta el siguiente comando en tu terminal:

```sh
aws route53 list-hosted-zones-by-name --dns-name tusitio.com \
  --query "HostedZones[0].Id" --output text | cut -d'/' -f3
```

Puedes crear el stack desde la consola de AWS o ejecutando el siguiente comando:

```
aws cloudformation create-stack --stack-name associate-cloudfront-origins --template-body file://template2.yaml --parameters ParameterKey=DomainName,ParameterValue=tusitio.com ParameterKey=HostedZoneId,ParameterValue=<HOSTED_ZONE_ID>
```

Puedes ejecutar un unico comando que realice las dos operaciones:

```
aws cloudformation create-stack \
  --stack-name associate-cloudfront-origins \
  --template-body file://template2.yaml \
  --parameters \
    ParameterKey=DomainName,ParameterValue=tusitio.com \
    ParameterKey=HostedZoneId,ParameterValue=$(aws route53 list-hosted-zones-by-name --dns-name tusitio.com --query "HostedZones[0].Id" --output text | cut -d'/' -f3)
```

---

### Redirección de múltiples URLs con patrones comunes

Si necesitas redirigir varias URLs que comparten un patrón (por ejemplo, todas las rutas bajo `/servicios/`) hacia una misma página de destino, puedes simplificar la configuración evitando crear múltiples `CacheBehavior` y reglas de redirección individuales.

**Alternativa recomendada:**

- En CloudFront, crea un solo `CacheBehavior` usando un patrón con comodín, por ejemplo:
  ```
  PathPattern: /servicios/*
  ```
  Esto enviará todas las solicitudes que comiencen con `/servicios/` al origen S3.

- En el archivo `redirects.json` del bucket S3, agrega una única regla con `"KeyPrefixEquals": "servicios/"` para redirigir todas esas rutas a una página específica, por ejemplo `/servicios/servicios-cloud`:

  ```json
  {
    "Condition": { "KeyPrefixEquals": "servicios/" },
    "Redirect": {
      "ReplaceKeyWith": "servicios/servicios-cloud",
      "HttpRedirectCode": "301"
    }
  }
  ```

De esta forma, todas las URLs bajo `/servicios/` serán redirigidas automáticamente a `/servicios/servicios-cloud` con código 301, sin necesidad de crear reglas individuales para cada una.

**Limitación:**  
S3 solo permite redirección por prefijo o nombre exacto, no soporta expresiones regulares avanzadas ni mantiene partes dinámicas del path. Para lógica más compleja, considera Lambda@Edge.

---

## 2. Agregar Nuevas Reglas de Redirección en redirects.json

El archivo [`redirects.json`](redirects.json) define las reglas de redirección para el bucket S3. Cada regla se agrega dentro del arreglo `"RoutingRules"` con la siguiente estructura:

```json
{
  "Condition": { "KeyPrefixEquals": "ruta/origen.html" },
  "Redirect": {
    "Protocol": "https",
    "HostName": "tusitio.com",
    "ReplaceKeyWith": "ruta/destino.html",
    "HttpRedirectCode": "301"
  }
}
```

---

## 3. Uso del Script put-bucket-website-config.sh

El script [`put-bucket-website-config.sh`](put-bucket-website-config.sh) permite aplicar la configuración de redirecciones al bucket S3 usando el archivo `redirects.json`.  
Este script utiliza la CLI de AWS para actualizar la configuración del sitio web del bucket, permitiendo que las reglas de redirección definidas en el archivo JSON sean efectivas.

### ¿Qué hace el script?
- Recibe como parámetros el nombre del bucket y la ruta al archivo JSON con las reglas de redirección.
- Ejecuta el comando `aws s3api put-bucket-website` para actualizar la configuración del bucket S3 con las reglas especificadas.

### Ejemplo de uso

Primero, da permisos de ejecución al script:

```sh
chmod +x put-bucket-website-config.sh
```

Luego, ejecuta el script pasando el nombre del bucket y la ruta al archivo JSON:

```sh
./put-bucket-website-config.sh <nombre_bucket> <ruta_json>
```

Donde `<nombre_bucket>` es el nombre de tu bucket S3 y `<ruta_json>` es la ruta al archivo `redirects.json` que contiene las reglas.

**Nota:**  
Asegúrate de tener configuradas tus credenciales de AWS y permisos suficientes para modificar la configuración del bucket.