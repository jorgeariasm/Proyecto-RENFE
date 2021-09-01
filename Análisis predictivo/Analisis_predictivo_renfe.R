##Formato Rmarkdown

---
title: "Análisis precios AVE"
Proyecto: Modelizacion predictiva para precios tickets AVE
Autor: Jorge Arias
Recurso: Codigo de desarrollo
output:
  html_document:
    df_print: paged
editor_options:
  chunk_output_type: console

---

#0. - Parametros

```{r}
options(scipen=999)#Desactiva la notacion cientifica
```


#1. - Preparacion del entorno
1.1 - Cargamos las librerias que vamos a utilizar

```{r}
#lista de paquetes que vamos a usar
paquetes <- c('data.table',#para leer y escribir datos de forma rapida
              'dplyr',#para manipulacion de datos
              'tidyr',#para manipulacion de datos
              'ggplot2',#para graficos
              'randomForest',#para crear los modelos
              'purrr',#para usar la funcion map que aplica la misma funciona a varios componentes de un dataframe
              'smbinning',#para calcular la para importancia de las variables
              'rpart',#para crear arboles de decision
              'rpart.plot',#para el grafico del arbol
              'Metrics',#para las metricas
              'h2o',#AutoML
              'lubridate' #para el tratamiento de fechas
              
)
#Crea un vector logico con si estan instalados o no
instalados <- paquetes %in% installed.packages()
#Si hay al menos uno no instalado los instala
if(sum(instalados == FALSE) > 0) {
  install.packages(paquetes[!instalados])
}
lapply(paquetes,require,character.only = TRUE)
```

1.2 - Cargamos los datos
Usamos fread de data.table para una lectura mucho mas rapida
```{r}
renfe <- fread('renfe.csv')
```


#2 - Analisis exploratorio
2.1 - Analisis exploratorio general y tipo de datos
```{r, message=TRUE, warning=TRUE}
glimpse(renfe)
as.data.frame(sort(names(renfe)))
str(renfe)
```

#Contenido dataset:
Podemos ver rápidamente que el archivo contiene 7.671.354 registros y 9 variables, dentro de las cuales destacan estaciones de origen y destino, horarios, clase de tren y precio, esta última sera la variable en la cual desarrollaremos nuestro modelo predictivo.

2.2 - Calidad de datos: Estadísticos básicos
Hacemos un summary, con lapply que sale en formato de lista y se lee mejor
```{r}
lapply(renfe,summary)
```

# Primeras observaciones:

Todos los datos son de tipo caracter, excepto el precio.
Hay que valorar si la fecha la debemos transformar para poderla trabajar mejor.
En la variable precio, encontramos un número muy alto de datos no encontrados.


2.3 - Calidad de datos: Análisis de nulos
```{r}
data.frame(colSums(is.na(renfe)))
```

Podemos observar que contiene demasiados datos nulos. Puede ser debido a un cambio de tren, adelantando el billete a coste cero o anulación del mismo.

Una opción que podría ser interesante es la de sustutuír los nulos por los precios de media, pero segmentando la media de cada una de las tarifas (Promo, turista, turista plus, preferente...) Pero esto cargaría cierto grado de error tratándose de la variable a predecir, por lo tanto: 
#Eliminamos registros nulos
```{r}
colSums(is.na(renfe))
renfe <- na.omit(renfe)
```

#Investigaremos cada variable un poco más:

2.3.1 - Vamos a conocer las diferentes tarifas existentes:
```{r}
renfe %>%                       
  group_by(fare) %>%      
  tally()  
```
Las más significativa es la tarifa ´promo´ con mas de 5 millones de registros de los 7 que tiene el dataframe, seguida de ´flexible´ y ´adulto ida´


2..3.2 - Vamos a conocer las diferentes clases de tren :
```{r}
 renfe %>%                       
  group_by(train_class) %>%      
  tally()  
```
La clase mas usada para viajar es ´turista´ con 5,4mill. de registros, seguida de ´preferente y ´turista plus´

2.3.3 - Conoceremos ahora los tipos de tren que hay en circulación:
```{r}
 renfe %>%                       
  group_by(train_type) %>%      
  tally()  
```
En este caso los trenes que tiene mayor número de circulaciones son los ´AVE´ coincidiendo con más de 5mill. de registros, seguido del ´Alvia´ e ´Intercity´

2.3.4 - Ahora vamos a conocer los principales orígenes y destinos 
```{r}
renfe %>%                       
  group_by(origin) %>%      
  tally()  
```

Los resultados muestran que sólo tenemos 5 orígenes y destinos en el dataset, combinaciones de trenes que van y vienen hacia Madrid, ciudad eje de toda la curulación.

#Tras estos primeros análisis, se puede observar también con facilidad, que el grueso de los datos están obtenidos por trenes ´AVE´, en sus 3 principales clases ´Preferente´, ´Turista Plus´ y ´Turista´ clases que además algunas coindiden  en los trenes ´Alvia´ e ´Intercity´

#Algunos gráficos:
```{r}
ggplot(data = renfe, aes(x = train_type, fill = as.factor(train_class))) + geom_bar() + 
  xlab("Tipo de Tren") + 
  ylab("Número de viajeros") + 
  ggtitle("Gráfico Viajeros por tipo de tren y clase ") +
  labs(fill = "Clases") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
```


```{r}
ggplot(data = renfe, aes(x = origin, fill = as.factor(train_type))) + 
  geom_bar() + 
  xlab("Origen") + 
  ylab("Número de viajeros") + 
  ggtitle("Gráfico Viajeros por origen y destino en función del tren ") +
  labs(fill = "Tipos de tren") + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
```

2.4 - Calidad de datos: Análisis de atípicos

2.4.1 - Analizamos las que son de tipo numerico: Precio

```{r}
out <- function(variable){
  t(t(head(sort(variable,decreasing = F),60))) #la doble traspuesta es un truco para que se visualice la salida, si no lo que crearia es una coleccion de dataframes que no se ven bien
}
lapply(renfe,function(x){
  if(is.double(x)) out(x)
})
```

Previamente había observado en los estadísticos básicos de la función Lapply que el precio máximo es de 342,80€, cantidad razonable. Pero tenía dudas sobre cuántos billetes a precio "cero" se podían encontrar. Para ello hago uso de esta fórmula y tan solo encuentro 51 registros. cantidad asumible. Si cambio el decreassing a True me da la tarifa máxima y coincide.

También investigo la desviación típica del precio, que me proporciona la varición del conjunto de datos:

```{r}
sd(renfe$price)
```

El resultado es de 25.68568

2.5 - Acciones resultado del analisis de calidad de datos y exploratorio

Tras los principales análisis y comprobar la calidad de los datos, podemos definir el trabajo a seguir: Nos centraremos en tres tipos de trenes: AVE, ALVIA e INTERCITY, en las principales clases: PREFERENTE; TURISTA PLUS Y TURISTA y las tarifas más demandadas: PROMO, FLEXIBLE y ADULTO IDA.
No eliminaremos ninguna categoría hasta saber la relación que puedan tener unas con otras.


#3 - Trasformación de datos

3.1. Cambio de formato en las fechas, están en formato caracter y podemos trabajarlas en el formato que viene de origen:

```{r}
renfe$insert_date <- as_datetime(renfe$insert_date)
renfe$start_date <- as_datetime(renfe$start_date)
renfe$end_date <- as_datetime(renfe$end_date)
```

Una vez transformado el formato, podemos volver a hacer un lapply para conocer los períodos de compra y viaje entre los que se encuentra el dataframe. 

```{r}
lapply(renfe,summary)
```
Todo transcurre en un período de 7 meses, de Abril a Octubre de 2019.

Fechas de compra: del 11 de abril al 22 de agosto
Fechas de inicio de viaje: del 12 de abril al 20 de octubre
Última llegada:  21 de octubre.

Nos centraremos en el período de compra, el cual finaliza el 22 de agosto.


#Creación de variables

3.2 - Crearemos una lista con todos los festivos del año examinado y posteriormente compararemos si en el df conicide con la fecha de salida, almacenando su resultado en la nueva variable "festivo" 
```{r}
fiestas <- (c("2019-01-01", "2019-04-19","2019-05-19","2019-08-15","2019-10-12","2019-11-01","2019-12-06","2019-12-25","2019-01-07","2019-02-28","2019-04-18","2019-12-09","2019-04-22","2019-12-26","2019-05-24","2019-09-11","2019-03-19","2019-04-22","2019-08-09","2019-05-17","2019-07-25"))

renfe <- renfe %>%
  mutate(fecha = as.character(date(start_date)),
         festivo = ifelse(fecha %in% fiestas, 1, 0))
```

3.3 - Dia de la semana de compra y de salida:

```{r}
renfe <- renfe %>%
  mutate(
   dia_compra = (wday(insert_date, label = TRUE, abbr = FALSE,week_start = getOption("lubridate.week.start", 1))),
   dia_salida = (wday(start_date, label = TRUE, abbr = FALSE,week_start = getOption("lubridate.week.start", 1))))
```

Hacemos una breve comprobación para saber los días de mayor afluencia de viajeros:

```{r}
renfe %>%
  group_by(dia_salida)%>%
  tally()
```

Podemos observar que entre semana hay un número muy similar de viajeros, despuntando, por poco, los Martes y Jueves. El sábado es el día de menor tráfico de viajeros.

Para comprobar si la fecha de salida y llegada son las mismas, creo la variable "mismo_dia" que me dara un valor logico:

```{r}
renfe <- renfe %>%
  mutate (mismo_dia = as.numeric(as.character((ifelse 
                        (end_date == start_date, '1','0')))))
```

```{r}
renfe <- renfe %>%
  mutate(
    fecha1 = as.character(date(end_date)),
    fecha2 = as.character(date(start_date)),
    mismo_dia = ifelse(fecha2 == fecha1, 1, 0))
```


3.4 - Semana del año de compra y de salida:

```{r}
renfe <- renfe %>%
  mutate(
    semana_ano_compra = week(insert_date),
    semana_ano_salida = week(start_date))
```

3.5 - Mes del año de compra y de salida:

```{r}
renfe <- renfe %>%
  mutate(
    mes_ano_compra = month(insert_date, label = F ),
    mes_ano_salida = month(start_date, label = F ))
```

3.6 - Creamos otra variable que nos determine la duración del viaje. Restando end_date y start_date.

```{r}
renfe <- renfe %>%
  mutate(duracion = round(difftime(end_date,start_date,units="hours"),2))
 
```

3.7 - Creamos la variable "antelacion"  que nos puede ayudar más adelante a saber si existe una relación estrecha entre la fecha de compra y el precio. Para ello restaremos start_date e insert_date.

```{r}
antelacion <- round(difftime(renfe$start_date,renfe$insert_date,units="days"),0)
```

3.8 - Discretizacion de la variable "antelacion"
Usando los estadísticos básicos he obtenido lo siguiente:
Media: 26 días, Mediana: 25 días, Moda: 22 días, Max.: 60 días. Aún así quiero establecer períodos semnales para discretizar la variable.

#Discretizamos manualmente
```{r}
renfe <- renfe %>%
  mutate(antelacion_DISC = as.factor(case_when(
      antelacion >= 49 ~ 'Dos_meses',
      antelacion < 49 & antelacion >= 42 ~ 'Mes_y_medio',
      antelacion < 42 & antelacion >= 35 ~ '5_semanas',
      antelacion < 35 & antelacion >= 28 ~ '4_semanas',
      antelacion < 28 & antelacion >= 21 ~ '3_semanas',
      antelacion < 21 & antelacion >= 14 ~ '2_semanas',
      antelacion < 14 & antelacion >= 7 ~ '1_semana',
      TRUE ~ 'Poca_antelacion')))

```

3.9 - Eliminamos variables no predictoras del dataset, todas son relacionadas con las fechas, las cuales han sido transformadas para obtener más información.

```{r}
renfe <- select(renfe, -insert_date,-end_date,-start_date,-fecha,-fecha1,-fecha2)
```

#Cache temporal
Vamos a guardar un cache de datos, de forma que cuando queramos seguir trabajando desde aqui no tengamos que volver a ejecutar todo
```{r}
saveRDS(renfe,'cacherenfe1.rds')
```

Cargamos el cache temporal
```{r}
renfe <- readRDS('cacherenfe1.rds')
```


#4 - Modelizacion. 

```{r}
set.seed(12345)
```

4.1 - Al no tener una columna ID, la creamos haciéndola coincidor con el número de filas del dataframe.

# Training (35% y 35%) y test (30%)

```{r}
renfe <- renfe %>% mutate(id = row_number())

#Dividimos el dataset en 70/30
temp <- renfe %>% sample_frac(.70)
#ahora creo dos train de 35% del dataset cada una
train1 <-temp %>% sample_frac(.50)
train2 <-anti_join(temp, train1, by = 'id')

#Creamos el 30% para el test, la funcion anti_join devuelve el restante de train
test  <- anti_join(renfe, temp, by = 'id')
#borramos temp
rm(temp)
```

4.2 - Identificamos las variables
```{r}
#Las independientes seran todas menos la id y la target (precio)
independientes <- setdiff(names(renfe),c('id','price'))
target <- 'price'
```

4.3 - Creamos la formula para usar en el modelo
```{r}
formula <- reformulate(independientes,target)
```

4.3.1 - Realizamos una regresión lineal múltiple, al ser la target una variable contínua.

```{r}
#Aumentamos la memoria de trabajo, para evitar problemas
memory.limit(size = 25000)

modelolm <- lm(formula, data = train1)
summary(modelolm)
```

#Resultado lm:
Los datos que nos da el modelo es que con todas las variables introducidas como predictores, tiene un R2 alta (0.8448), es capaz de explicar el 84,48% de la variabilidad observada en el precio. El p-value es inferior a 0,05, lo que me asegura que confirma que el modelo es bueno.

Métricas: RMSE

```{r}
rmse <- sqrt(mean(modelolm$residuals^2))
rmse
```

El valor obtenido es 10.12592, lo que me indica que la predicción de precios varía en 10€, lo que significa que el modelo reduce en 2,5 veces la variabilidad del error promedio al calcular el precio.

#Cache modelo
Vamos a guardar un cache de datos, de forma que cuando queramos seguir trabajando desde aqui no tengamos que volver a ejecutar todo
Evaluamos las predicciones del modelo


```{r}
saveRDS(modelolm,'modelo_renfe.rds')
saveRDS(test, 'testrenfe')
```


Evaluamos las predicciones del modelo
```{r}
predicciones <- round(predict(modelolm, newdata = test, type='response'),2)
```

Cargamos el cache modelo
```{r}
modelolm <- readRDS('modelo_renfe.rds')
test <- readRDS('testrenfe.rds')
```

#Comparamos el precio real frente a la prediccion:

```{r}
#Creamos una secuencia de numeros para abarcar el eje x desde 1 hasta el número de filas
 
x<- seq(1, (nrow(test)))

#creamos nueva variable que contiene los datos resumidos de la tabla
compara <- as.data.table(cbind(x, test$price, predicciones))

colnames(compara) <- c("x","precio", "prediccion")

compara$precio <- as.numeric(compara$precio)
compara$prediccion <- as.numeric(compara$prediccion)

df<- sample_n(compara, size= 100, replace = F)

#Gráfico de comparacion de precios
ggplotly(
ggplot(df, aes(x=x)) + 
  geom_line(aes(y=precio), colour="red") +  
  geom_line(aes(y=prediccion), colour="#33D5FF") +
  labs(x = "", y = "Euros", colour = "Legend") +
    scale_color_manual(values = colours)+
  theme_bw() +
  theme(axis.title.x = element_blank(),
        axis.text.x = element_blank()),
  tooltip = 'text'
)
```


