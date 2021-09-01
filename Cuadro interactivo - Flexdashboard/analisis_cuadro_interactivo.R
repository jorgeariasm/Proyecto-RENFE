##Formato Rmarkdown

---
title: "Análisis Renfe" 
author: "Elaborado por: Jorge Arias. - Proyecto DS4B"
output: 
  flexdashboard::flex_dashboard:
editor_options: 
  chunk_output_type: console
---

```{r include = F}
#lista de paquetes que vamos a usar
paquetes <- c('data.table',#para leer y escribir datos de forma rapida
              'dplyr',#para manipulacion de datos
              'tidyr',#para manipulacion de datos
              'ggplot2',#para graficos
              'lubridate', #para el tratamiento de fechas
              'flexdashboard',
              'DT',
              'tidyverse',
              'plotly',
              'knitr',
              'leaflet'
             
              
)
#Crea un vector logico con si estan instalados o no
instalados <- paquetes %in% installed.packages()
#Si hay al menos uno no instalado los instala
if(sum(instalados == FALSE) > 0) {
  install.packages(paquetes[!instalados])
}
lapply(paquetes,require,character.only = TRUE)
```


```{r setup, include = F}
options(scipen=999)#Desactiva la notacion cientifica
```


```{r, include = F}
#Cargamos los datos
renfe <- read_csv('renfe.csv')

#Revisamos y entendemos los datos
glimpse(renfe)
View(renfe)

#Eliminamos registros nulos
colSums(is.na(renfe))
renfe <- na.omit(renfe)

#Cambio de formato de fechas
renfe$insert_date <- as_datetime(renfe$insert_date)
renfe$start_date <- as_datetime(renfe$start_date)
renfe$end_date <- as_datetime(renfe$end_date)


```

 
 
```{r, include = F}
#Cálculos a usar en el dashboard

#Total de Viajeros
total_viajeros <- nrow(renfe)

#Número de circulaciones
num_circulaciones <- nrow( renfe%>%                       
     group_by(start_date, train_type) %>%      
     tally())

#Recaudación por billetes
recaudacion <- sum(renfe$price)

#Meses
mes <- month(renfe$start_date, label = TRUE)

```

---
Análisis de viajeros de líneas Alta Velocidad Española - Visión general

INDICADORES CLAVE {data-orientation=rows}
===================================================

## Fila 1  {data-height=200}


### Número total de viajeros
```{r}
valueBox(prettyNum(total_viajeros,big.mark = '.'),
         icon = "fas fa-suitcase",
         caption = 'Número de viajeros totales',
         color = 'red')
```

### Número de circulaciones
```{r}
valueBox(prettyNum(num_circulaciones,big.mark = '.'),
         icon = "fas fa-train",
         caption = 'Número de circulaciones',
         color = 'blue')
```

### Recaudacion por billetes
```{r}
valueBox(prettyNum(recaudacion, big.mark = '.'),
         icon = "fa-eur",
         caption = 'Recaudación por venta de billetes',
         color = 'green')
```

### Comentario en texto libre {.no-title}

Información obtenida por datos públicos emitidos por la compañía ferroviaria Renfe Viajeros S.A., en un período concreto del año 2019.


## Fila 2  

### CONEXIONES CON MADRID


```{r}
ggplotly(
ggplot(renfe) + 
  geom_bar(mapping = aes(x = mes, fill = destination), position = "dodge")+
  xlab("Mes") + 
  ylab("Número de viajeros") + 
  labs(fill = "Destinos") +
  coord_flip(),
  tooltip = 'text'
)
```



### MAPA DE DESTINOS
```{r}
dest_df <- data.frame (
  lat = c(41.38879, 39.46975, 37.38283, 42.5466400),
  lon = c(2.15899, -0.37739, -5.97317, -6.5961900))

orig_df <- data.frame (lat = c(rep.int(40.4165, nrow(dest_df))),
                   long = c(rep.int(-3.70256,nrow(dest_df)))
                  )


orig_df$sequence <- c(sequence = seq(1, length.out = nrow(orig_df), by=2))
dest_df$sequence <- c(sequence = seq(2, length.out = nrow(orig_df), by=2))

library("sqldf")
q <- "
SELECT * FROM orig_df
UNION ALL
SELECT * FROM dest_df
ORDER BY sequence
"
poly_df <- sqldf(q)


m <- leaflet() %>% 
    setView(lat  = 40.416775, lng = -3.703790, zoom = 5)%>%
    addTiles() %>%  
    addPolylines(data = poly_df, lng = ~long, lat = ~lat, weight = 2,
    opacity = 3 ) %>%
    addMarkers(lat=40.4165, lng=-3.70256, popup="Madrid")%>%
    addMarkers(lat=41.38879, lng=2.15899, popup="Barcelona")%>%
    addMarkers(lat=39.46975, lng=-0.37739, popup="Valencia")%>%
    addMarkers(lat=37.38283, lng=-5.97317, popup="Sevilla")%>%
    addMarkers(lat=42.5466400, lng=-6.5961900, popup="Ponferrada")
m %>% addProviderTiles(providers$CartoDB.Positron)
```



VIAJEROS {data-orientation=column}
===================================================

VIAJEROS POR TIPOLOGÍA DE TREN, CLASE ELEGIDA Y TARIFA

## Columna 1 {data-width=400}

### TIPOS DE TREN (MATERIAL RODANTE) 

```{r}
df <- renfe
df <- df %>% group_by(train_type)
df <- df %>% summarize(count = n())

fig <- df %>% plot_ly(labels = ~train_type, values = ~count,
        textposition = 'inside',
        textinfo = 'label+percent')

fig <- fig %>% add_pie(hole = 0.5)
fig <- fig %>% layout( showlegend = F,
                      xaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
                      yaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE))


fig
```

## Columna 2 {data-width=400}
### CLASE ELEGIDA 

```{r}
clases<- renfe %>%                       
        group_by(train_class) %>%      
        tally()
ggplotly(
ggplot(clases, aes(x =train_class, y=n)) + 
  geom_bar(stat = 'identity') +
  xlab("Clases")+
  ylab("Número de viajeros") + 
  theme_bw()+
  theme(axis.text.x = element_text(angle = 90, hjust = 1)),
  tooltip = 'text'
)
```


## Columna 3
### TARIFA 

```{r}

ggplotly(
ggplot(renfe) + 
  geom_bar(mapping = aes(x = fare, fill = fare))+
  xlab("Tarifa") + 
  ylab("Número de viajeros") + 
  labs(fill = "Tarifa") +
  coord_flip(),
  tooltip = 'text'
)
```


PRECIOS
===================================================

COMPARACIÓN ENTRE PRECIOS DE BILLETES Y PREVISIÓN OBTENIDA CON MACHINE LEARNING

### Comentario en texto libre {.no-title}
Para el modelo de ML he utilizado una regresión lineal múltiple al ser la target una variable continua. Los datos que nos da el modelo es que con todas las variables introducidas como predictores, tiene un R2 alta (0.8448), es capaz de explicar el 84,48% de la variabilidad observada en el precio. El p-value es inferior a 0,05, lo que me asegura que confirma que el modelo es bueno.

En la evaluación, el valor obtenido del RMSE es de 10.12592, indicador que la predicción de precios varía en 10€ aprox., lo cual significa que el modelo reduce en 2,5 veces la variabilidad del error promedio al calcular el precio.

A contunuación reflejo una gráfica con muestra aleatoria para comparar el modelo y el precio real.

```{r,include = F}
#Cargamos el cache modelo
modelolm <- readRDS('modelo_renfe.rds')
test <- readRDS('testrenfe.rds')
```


```{r,include = F}
#Evaluamos las predicciones del modelo
predicciones <- round(predict(modelolm, newdata = test, type='response'),2)
```


```{r,include = F}
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

```{r}
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