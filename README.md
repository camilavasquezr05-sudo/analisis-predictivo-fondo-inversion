# Predicción del retorno mensual del ETF CFIETFCC mediante indicadores macroeconómicos de Chile y Estados Unidos

**Trabajo Integrado Grupal (TIG) — Ciencia de Datos**<br>
**Institución:** Universidad Andrés Bello (UNAB) — Primavera 2026<br>
**Docente:** Felipe Cárcamo Jiménez<br>
**Integrantes:** Milan Yutronic · Camila Vasquez · Camila Gallardo · Paula Meyer<br>
**Herramientas:** R y RStudio<br>
**Repositorio oficial:** https://github.com/camilavasquezr05-sudo/analisis-predictivo-fondo-inversion

## 1. Descripción del proyecto

Este proyecto evalúa si los indicadores macroeconómicos de Chile y Estados Unidos, junto con el tipo de cambio USD/CLP, permiten predecir el retorno mensual del ETF de bonos corporativos chilenos **CFIETFCC**.

El análisis aborda dos tareas de aprendizaje supervisado:

- **Regresión:** estimar el retorno porcentual del mes siguiente.
- **Clasificación:** identificar si el retorno del mes siguiente será positivo o no positivo.

Se comparan modelos estadísticos y de aprendizaje automático con reglas simples de referencia, para determinar si su complejidad se traduce en una mejora predictiva fuera de muestra.

## 2. Pregunta de investigación

**¿Permiten los indicadores macroeconómicos y el tipo de cambio, conocidos al cierre de un mes, predecir el retorno del ETF CFIETFCC en el mes siguiente mejor que una regla simple de referencia?**

Se modela el retorno en lugar del precio porque representa la variación que interesa anticipar y reduce el riesgo de obtener relaciones engañosas entre series con tendencia.

## 3. Objetivos

### Objetivo general

Evaluar la capacidad predictiva de variables macroeconómicas y cambiarias sobre el retorno mensual del ETF CFIETFCC.

### Objetivos específicos

1. Construir una base mensual utilizando información disponible al cierre de cada mes.
2. Describir la evolución de los retornos y su relación con los predictores mediante análisis exploratorio.
3. Entrenar y comparar modelos de regresión y clasificación.
4. Evaluar su desempeño frente a líneas base.
5. Analizar si incorporar el tipo de cambio mejora las predicciones.
6. Interpretar los resultados, sus implicancias y sus limitaciones.

## 4. Hipótesis de investigación

Estas hipótesis se evalúan mediante el desempeño fuera de muestra. La comparación de métricas no constituye, por sí sola, una prueba formal de significancia estadística de las diferencias entre modelos.

| Hipótesis | Planteamiento | Criterio de evaluación |
|---|---|---|
| H1: predicción del retorno | Los predictores permiten estimar el retorno mensual mejor que el promedio histórico del tramo de entrenamiento. | Obtener un RMSE menor que la línea base. |
| H2: dirección del retorno | Los modelos permiten distinguir alzas y caídas mejor que predecir siempre la clase mayoritaria. | Comparar accuracy, precision, recall y especificidad con la línea base. |

## 5. Datos utilizados

La unidad de observación es el **mes**. La muestra efectiva contiene **78 observaciones**:

- **Meses de los predictores:** abril de 2020 a septiembre de 2026.
- **Meses de los retornos objetivo:** mayo de 2020 a octubre de 2026.

### Archivos de entrada

| Archivo | Contenido | Uso en el proyecto |
|---|---|---|
| `CFIETFCC.xlsx` | Precio de cierre ajustado del ETF | Cálculo de retornos |
| `TPM_Chile.xlsx` | Tasa de política monetaria de Chile | Predictor |
| `TPM_EEUU.xlsx` | Tasa de fondos federales de EE. UU. | Predictor |
| `Inflación_Chile.xlsx` | Variación de la UF a 12 meses | Aproximación de inflación chilena |
| `Inflación_EEUU.xlsx` | Inflación de EE. UU. disponible a cada fecha | Predictor |
| `Desempleo_Chile.xlsx` | Desocupación de Chile disponible a cada fecha | Predictor |
| `Desempleo_EEUU.xlsx` | Desempleo de EE. UU. disponible a cada fecha | Predictor |
| `IMACEC_Chile.xlsx` | Variación del IMACEC a 12 meses disponible a cada fecha | Predictor |
| `valor del dolar Chile.xlsx` | Tipo de cambio USD/CLP | Nivel y variación mensual |
| `IMACEC_EEUU.xlsx` | Serie identificada como CPI de referencia de EE. UU. | Excluida del modelamiento |

### Consideraciones sobre los datos

- El archivo `IMACEC_EEUU.xlsx` contiene información de precios y no un indicador de actividad estadounidense. Se excluye por duplicar información de inflación.
- La variación de la UF se utiliza como aproximación de la inflación chilena; no equivale al IPC contemporáneo.
- Se utilizan las columnas que representan información disponible a cada fecha.
- Noviembre de 2026 se excluye porque los datos del ETF no cubren el mes completo.

## 6. Variables del modelo

### Variables objetivo

| Variable | Definición | Problema |
|---|---|---|
| `ret_sig` | Retorno porcentual del ETF en el mes siguiente | Regresión |
| `sube_sig` | “Sube” si el retorno siguiente es mayor que cero; “Baja” en caso contrario | Clasificación |

La etiqueta **“Baja” incluye retornos iguales a cero**.

### Variables construidas

| Variable | Definición |
|---|---|
| `ret_mes` | Retorno porcentual del ETF en el mes actual |
| `d_tpm_cl` | Cambio mensual de la TPM de Chile |
| `d_tpm_us` | Cambio mensual de la tasa de EE. UU. |
| `ret_dolar` | Variación porcentual mensual del USD/CLP |

La versión utiliza **12 predictores**: siete indicadores macroeconómicos, el nivel y la variación del dólar, los cambios mensuales de ambas tasas de política y el retorno actual del ETF.

## 7. Metodología

### Preparación de datos

1. Lectura de los archivos Excel.
2. Estandarización de fechas y valores numéricos.
3. Selección del último dato disponible de cada mes.
4. Unión de las series por mes.
5. Construcción de retornos, cambios de tasas y variables objetivo.
6. Revisión y eliminación de observaciones incompletas.
7. Análisis exploratorio de distribuciones, evolución temporal y correlaciones.

### División temporal

La separación de los datos respeta el orden cronológico.

| Conjunto | Meses de los predictores | Observaciones | Propósito |
|---|---|---:|---|
| Entrenamiento | Abril de 2020 a enero de 2024 | 46 | Ajustar los modelos |
| Validación | Febrero de 2024 a mayo de 2025 | 16 | Comparar y seleccionar modelos |
| Prueba | Junio de 2025 a septiembre de 2026 | 16 | Evaluar el desempeño final |

Después de comparar los modelos en validación, se reentrenan con las 62 observaciones de entrenamiento y validación y se evalúan en el conjunto de prueba.

### Prevención de fuga de información

- Los predictores corresponden al mes `t` y la variable objetivo al mes `t+1`.
- Se utilizan datos macroeconómicos disponibles al cierre del mes correspondiente.
- La partición es cronológica y no aleatoria.
- Las líneas base se calculan utilizando únicamente el tramo disponible para entrenar.
- El conjunto de prueba se reserva para la evaluación final.

## 8. Modelos implementados

| Problema | Modelo | Motor en R |
|---|---|---|
| Regresión | Regresión lineal | `lm` |
| Regresión | Árbol de regresión | `rpart` |
| Regresión | Bosque aleatorio | `ranger` |
| Clasificación | Regresión logística | `glm` |
| Clasificación | Árbol de clasificación | `rpart` |
| Clasificación | Bosque aleatorio | `ranger` |

### Líneas base

- **Regresión:** predecir el retorno promedio del tramo utilizado para entrenar.
- **Clasificación:** predecir siempre la clase mayoritaria del tramo utilizado para entrenar.

### Configuración documentada

| Parámetro | Configuración |
|---|---|
| Semilla aleatoria | `123` |
| Profundidad máxima del árbol | `3` |
| Parámetro `min_n` | `5` |
| Número de árboles del bosque | `500` |
| Importancia de variables | Por permutación |
| Búsqueda en grilla | No realizada |

## 9. Métricas de evaluación

### Regresión

- **MAE:** error absoluto medio.
- **RMSE:** raíz del error cuadrático medio.

Ambas métricas se expresan en **puntos porcentuales de retorno mensual**. El criterio principal de selección es el menor RMSE en validación.

### Clasificación

- **Accuracy:** proporción total de predicciones correctas.
- **Precision:** proporción de alzas reales entre las observaciones predichas como “Sube”.
- **Recall:** proporción de alzas correctamente identificadas.
- **Especificidad:** proporción de caídas correctamente identificadas.
- **Matriz de confusión:** distribución de aciertos y errores por clase.

La clase positiva es **“Sube”**. Con el orden de niveles `c("Baja", "Sube")`, las métricas utilizan `event_level = "second"`.

## 10. Principales resultados

Los siguientes resultados corresponden a la evaluación de los modelos en el conjunto de prueba.

### Regresión: conjunto de prueba

| Modelo | MAE | RMSE |
|---|---:|---:|
| Línea base: promedio | **0,381** | **0,533** |
| Bosque aleatorio | 0,422 | 0,544 |
| Regresión lineal | 0,509 | 0,653 |
| Árbol de regresión | 0,557 | 0,665 |

Ningún modelo de la versión completa supera el RMSE de la línea base en el conjunto de prueba.

### Clasificación: conjunto de prueba

| Modelo | Accuracy | Precision | Recall | Especificidad |
|---|---:|---:|---:|---:|
| Línea base: siempre “Sube” | 0,813 | 0,813 | 1,00 | 0,00 |
| Regresión logística | 0,813 | 0,813 | 1,00 | 0,00 |
| Bosque aleatorio | 0,813 | 0,813 | 1,00 | 0,00 |
| Árbol de clasificación | 0,500 | 0,778 | 0,54 | 0,33 |

La regresión logística y el bosque predicen “Sube” en los 16 meses de prueba, reproduciendo la línea base.

El árbol identifica una de las tres caídas, pero clasifica incorrectamente seis meses de alza como caídas.

### Evaluación de las hipótesis

- **H1:** no se obtiene evidencia favorable en la versión completa; la línea base presenta menor RMSE.
- **H2:** no se observa una mejora conjunta convincente frente a la clase mayoritaria. El árbol detecta algunas caídas, pero reduce considerablemente la exactitud.

La inflación chilena presenta una asociación negativa significativa al 5 % en la regresión lineal reportada. Su interpretación requiere considerar la muestra pequeña, la multicolinealidad y la evaluación de múltiples coeficientes.

## 11. Dependencias

### Software

- **R 4.1 o superior.**
- **RStudio**, opcional como entorno de desarrollo.

### Paquetes de R

- `tidyverse`
- `tidymodels`
- `ranger`
- `rpart`
- `readxl`
- `writexl`

Instalar los paquetes desde la consola de R:

```r
install.packages(c(
  "tidyverse",
  "tidymodels",
  "ranger",
  "rpart",
  "readxl",
  "writexl"
))
```

## 12. Instrucciones de ejecución

El repositorio incluye el código y todos los archivos Excel necesarios.

1. Crear una carpeta en el computador (por ejemplo, `proyecto_CFIETFCC`).
2. Descargar en esa carpeta el archivo `modelo_CFIETFCC.R` y todos los archivos `.xlsx` del repositorio. Para cada uno: abrir el archivo en GitHub y presionar el botón de descarga (**Download raw file**).
3. Abrir `modelo_CFIETFCC.R` en RStudio.
4. Ir a **Session → Set Working Directory → To Source File Location**.
5. Instalar los paquetes de la sección 11 (solo la primera vez).
6. Ejecutar el script con el botón **Source** o con:

```r
source("modelo_CFIETFCC.R", encoding = "UTF-8")
```

Los resultados se guardan en `resultados_TIG_CFIETFCC.xlsx`.

**Importante:** todos los archivos deben quedar en la misma carpeta y no se deben renombrar, porque el script los busca por su nombre exacto.

### Salidas esperadas

- Base mensual procesada.
- Análisis exploratorio y gráficos.
- Métricas de regresión y clasificación.
- Matrices de confusión.
- Coeficientes de regresión.
- Importancia de variables.
- Predicciones del conjunto de prueba.

El archivo de resultados documentado en el informe es `resultados_TIG_CFIETFCC.xlsx`.

## 13. Fuentes de datos

| Datos | Fuente |
|---|---|
| Precio histórico del ETF | [Yahoo Finance — CFIETFCC.SN](https://finance.yahoo.com/quote/CFIETFCC.SN/history/) |
| UF | [Banco Central de Chile — UF e IVP](https://si3.bcentral.cl/Siete/ES/Siete/Cuadro/CAP_PRECIOS/MN_CAP_PRECIOS/UF_IVP_DIARIO) |
| Desempleo de EE. UU. | [FRED — UNRATE](https://fred.stlouisfed.org/series/UNRATE) |
| IMACEC de Chile | [Banco Central de Chile — IMACEC](https://si3.bcentral.cl/Siete/ES/Siete/Cuadro/CAP_CCNN/MN_CCNN76/CCNN2018_IMACEC_01_A?cbFechaInicio=2019&cbFechaTermino=2026&cbFrecuencia=MONTHLY&cbCalculo=NONE&cbFechaBase=) |
| TPM de Chile | [Banco Central de Chile — Tasa de política monetaria](https://si3.bcentral.cl/Bdemovil/BDE/Series/MOV_SC_TI1) |
| Tasa efectiva de fondos federales de EE. UU. | [FRED — Federal Funds Effective Rate (DFF)](https://fred.stlouisfed.org/series/DFF) |
| IPC e inflación de EE. UU. | [U.S. Bureau of Labor Statistics — Consumer Price Index](https://www.bls.gov/cpi/) |
| Desempleo de Chile | [Instituto Nacional de Estadísticas — Ocupación y desocupación](https://www.ine.gob.cl/estadisticas-por-tema/mercado-laboral/ocupacion-y-desocupacion) |
| Dólar observado USD/CLP | [Banco Central de Chile — Tipos de cambio y paridades](https://www.bcentral.cl/es/web/banco-central/areas/estadisticas/tipos-de-cambios-y-paridades) |

## 14. Limitaciones

- Muestra de 78 observaciones y solo 16 meses de prueba.
- Predominio de meses con retorno positivo.
- Pocas caídas en el conjunto de prueba.
- Correlación elevada entre varios predictores.
- Ausencia de tasas de bonos y spreads corporativos.
- Cambios económicos importantes durante el período.
- Uso de un único corte temporal de validación y prueba.
- Posible influencia de la tendencia del dólar en nivel.
- Clasificación de retornos apenas negativos como caídas, aunque su magnitud económica sea mínima.

Los resultados describen el desempeño en esta muestra. No demuestran que la información macroeconómica carezca de utilidad en otros períodos, activos o modelos.

## 15. Conclusiones

En la muestra analizada, los modelos de la versión completa no mejoran la predicción del retorno frente a la regla de utilizar el promedio histórico del tramo de entrenamiento.

En clasificación, la regresión logística y el bosque reproducen la clase mayoritaria. El árbol identifica algunas caídas, pero genera errores que limitan su utilidad.

Agregar el dólar no produce una mejora consistente. La asociación observada entre inflación chilena y retorno tampoco se traduce en una ventaja predictiva fuera de muestra.

El proyecto destaca la importancia de comparar los modelos con líneas base, respetar el orden temporal e interpretar las métricas considerando el contexto económico.

## 16. Uso de inteligencia artificial

Se utilizó Claude como apoyo para revisar la estructura de los datos, proponer la organización del código, identificar riesgos de fuga de información y revisar la interpretación de métricas.

El equipo es responsable de verificar el código, las fuentes, las decisiones metodológicas y la concordancia entre los resultados y la documentación.

## 17. Licencias 

Los datos y materiales de terceros conservan sus respectivas condiciones de uso. Su disponibilidad pública no implica autorización automática para redistribuirlos.

## 18. Referencias metodológicas

- Kuhn, M., & Silge, J. (2022). *Tidy Modeling with R*. O’Reilly Media. [https://www.tmwr.org/](https://www.tmwr.org/)

- Wickham, H., Çetinkaya-Rundel, M., & Grolemund, G. (2023). *R for Data Science* (2.ª ed.). O’Reilly Media. [https://r4ds.hadley.nz/](https://r4ds.hadley.nz/)

- Hyndman, R. J., & Athanasopoulos, G. (2021). *Forecasting: Principles and Practice* (3.ª ed.). OTexts. [https://otexts.com/fpp3/](https://otexts.com/fpp3/)
