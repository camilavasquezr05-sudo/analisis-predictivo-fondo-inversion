# Predicción del retorno mensual del ETF CFIETFCC mediante indicadores macroeconómicos de Chile y Estados Unidos

**Trabajo Integrado Grupal (TIG) — Ciencia de Datos**<br>
**Institución:** Universidad Andrés Bello (UNAB) — Primavera 2026<br>
**Docente:** Felipe Cárcamo Jiménez<br>
**Integrantes:** Milan Yutronic · Camila Vasquez · Camila Gallardo · Paula Meyer<br>
**Herramientas:** R y RStudio<br>
**Repositorio oficial:** https://github.com/camilavasquezr05-sudo/analisis-predictivo-fondo-inversion

## 1. Descripción del proyecto

Este proyecto evalúa si los indicadores macroeconómicos de Chile y Estados Unidos y el tipo de cambio USD/CLP permiten predecir el retorno mensual del ETF de bonos corporativos chilenos CFIETFCC.

El análisis aborda dos tareas: estimar el retorno del mes siguiente y clasificar si este será positivo o no. Se comparan regresiones, árboles de decisión y bosques aleatorios con reglas simples de referencia.

## 2. Pregunta de investigación

¿Permiten los indicadores macroeconómicos y el tipo de cambio, conocidos al cierre de un mes, predecir el retorno del ETF CFIETFCC en el mes siguiente mejor que una regla simple?

## 3. Objetivos

- Evaluar la capacidad predictiva de variables macroeconómicas y cambiarias sobre el retorno mensual del ETF.
- Explorar la relación entre los indicadores y el rendimiento del fondo.
- Comparar modelos de regresión y clasificación con reglas simples de referencia.
- Determinar si incorporar el tipo de cambio mejora las predicciones.
- Interpretar los resultados considerando el riesgo y el costo de oportunidad para un inversionista.

## 4. Datos utilizados

El estudio utiliza 78 observaciones mensuales y ocho series económicas: tasas de política monetaria, inflación y desempleo de Chile y Estados Unidos, IMACEC de Chile y tipo de cambio USD/CLP.

Se incorporan también variables construidas, como el retorno del mes actual, los cambios mensuales de las tasas y la variación mensual del dólar, hasta completar 12 predictores.

La inflación chilena se aproxima mediante la variación de la UF a 12 meses.

## 5. Metodología

Se realiza preparación de datos, análisis exploratorio y entrenamiento de modelos supervisados.

La muestra se divide cronológicamente en:
- Entrenamiento: 46 meses.
- Validación: 16 meses.
- Prueba: 16 meses.

Se utiliza únicamente información disponible al momento de realizar cada predicción, para evitar incorporar datos futuros.

**Regresión:** regresión lineal, árbol de regresión y bosque aleatorio.

**Clasificación:** regresión logística, árbol de clasificación y bosque aleatorio.

Los modelos se comparan con reglas de referencia basadas en el promedio y la clase mayoritaria del conjunto de entrenamiento.

## 6. Principales resultados

Ningún modelo superó a la regla simple de referencia en validación ni en prueba.

En regresión, predecir el retorno promedio obtuvo un RMSE de 0,533 puntos porcentuales en prueba, frente a 0,544 del bosque aleatorio.

Agregar el dólar no mejoró la capacidad predictiva. La inflación chilena presentó una asociación estadística negativa en la regresión lineal, pero esto no se tradujo en una ventaja predictiva fuera de muestra.

Los resultados corresponden a la muestra y metodología utilizadas y no establecen relaciones causales.
