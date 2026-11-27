# =====================================================================
# TIG Ciencia de Datos - Predicción del retorno mensual del ETF CFIETFCC
# Modelo principal: 12 predictores, incluido USD/CLP y su variación mensual.
# Ejecutar desde la RAÍZ del repositorio:  source("modelo_CFIETFCC.R")
# La instalación de paquetes está descrita en el README.md
# =====================================================================

# ---- 0. Paquetes y carpetas -----------------------------------------
library(tidyverse)
library(tidymodels)
library(readxl)
library(ranger)
library(rpart)
library(writexl)

# Carpeta para guardar los gráficos (se crea si no existe)
dir_graficos <- file.path("resultados", "graficos")
dir.create(dir_graficos, recursive = TRUE, showWarnings = FALSE)

# Muestra el gráfico (print) y lo guarda como PNG (ggsave)
guardar_grafico <- function(grafico, archivo, ancho = 8, alto = 5) {
  print(grafico)
  ggplot2::ggsave(
    filename = file.path(dir_graficos, archivo),
    plot = grafico, width = ancho, height = alto, dpi = 300
  )
}

CFIETFCC        <- readxl::read_xlsx("datos/CFIETFCC.xlsx")
Desempleo_Chile <- readxl::read_xlsx("datos/Desempleo_Chile.xlsx")
Desempleo_EEUU  <- readxl::read_xlsx("datos/Desempleo_EEUU.xlsx")
IMACEC_Chile    <- readxl::read_xlsx("datos/IMACEC_Chile.xlsx")
IMACEC_EEUU     <- readxl::read_xlsx("datos/IMACEC_EEUU.xlsx")
Inflación_Chile <- readxl::read_xlsx("datos/Inflación_Chile.xlsx")
Inflación_EEUU  <- readxl::read_xlsx("datos/Inflación_EEUU.xlsx")
TPM_Chile       <- readxl::read_xlsx("datos/TPM_Chile.xlsx")
TPM_EEUU        <- readxl::read_xlsx("datos/TPM_EEUU.xlsx")
Dolar_Chile     <- readxl::read_xlsx("datos/valor del dolar Chile.xlsx")


# ---- 1. Función de preparación de series ya cargadas ----------------
# Toma un data frame ya leído desde Excel, extrae la columna 1 (fecha)
# y la columna de valor indicada, estandariza tipos de datos y conserva
# el ÚLTIMO registro disponible de cada mes (cierre mensual).
# Si conservar_fecha = TRUE, agrega la columna fecha_cierre con la fecha
# del último dato observado en cada mes (sirve para detectar meses incompletos).
preparar_serie <- function(df, col_valor, nombre, formato_fecha = "%Y-%m-%d",
                           conservar_fecha = FALSE) {
  serie <- df |>
    dplyr::select(fecha = 1, valor = dplyr::all_of(col_valor))
  
  # Estandarizar fecha (maneja formato Date/POSIXct, serial de Excel o texto)
  if (inherits(serie$fecha, c("Date", "POSIXct", "POSIXlt"))) {
    serie <- serie |> dplyr::mutate(fecha = as.Date(fecha))
  } else if (is.numeric(serie$fecha)) {
    serie <- serie |> dplyr::mutate(fecha = as.Date(fecha, origin = "1899-12-30"))
  } else {
    serie <- serie |> dplyr::mutate(fecha = as.Date(as.character(fecha), format = formato_fecha))
  }
  
  # Estandarizar valor numérico (maneja números directos o texto con coma decimal)
  if (!is.numeric(serie$valor)) {
    serie <- serie |>
      dplyr::mutate(
        valor = readr::parse_number(
          as.character(valor),
          locale = readr::locale(decimal_mark = ",")
        )
      )
  }
  
  resultado <- serie |>
    dplyr::filter(!is.na(fecha), !is.na(valor)) |>
    dplyr::arrange(fecha) |>
    dplyr::mutate(mes = as.Date(format(fecha, "%Y-%m-01"))) |>
    dplyr::group_by(mes) |>
    dplyr::summarise(
      valor        = dplyr::last(valor),
      fecha_cierre = dplyr::last(fecha),
      .groups = "drop"
    ) |>
    dplyr::rename(!!nombre := valor)
  
  if (!conservar_fecha) {
    resultado <- resultado |> dplyr::select(-fecha_cierre)
  }
  resultado
}


# ---- 2. Limpieza mensual de cada serie ------------------------------
# Verifica con names(CFIETFCC), names(TPM_Chile), etc. que el número
# de columna coincida con la variable que quieres extraer en cada Excel.
etf       <- preparar_serie(CFIETFCC,        7,  "precio_etf", conservar_fecha = TRUE)
tpm_cl    <- preparar_serie(TPM_Chile,       2,  "tpm_cl")
tpm_us    <- preparar_serie(TPM_EEUU,        2,  "tpm_us")
inf_cl    <- preparar_serie(Inflación_Chile, 5,  "inf_cl")
inf_us    <- preparar_serie(Inflación_EEUU,  10, "inf_us",  "%d-%m-%y")
des_cl    <- preparar_serie(Desempleo_Chile, 6,  "des_cl")
des_us    <- preparar_serie(Desempleo_EEUU,  6,  "des_us",  "%d-%m-%y")
imacec_cl <- preparar_serie(IMACEC_Chile,    8,  "imacec_cl")

dolar_cl  <- preparar_serie(Dolar_Chile,     2,  "dolar_cl")

# Nota: IMACEC_EEUU no se integra porque contiene CPI de EE.UU. y duplica inf_us.
# El dólar sí se integra: nivel (dolar_cl) y variación mensual (ret_dolar).

# Descartar el último mes del ETF SOLO si está incompleto.
# Un mes se considera completo si el último dato del ETF cae a menos de
# 4 días del fin de mes (tolerancia por fines de semana y feriados).
ultimo_mes   <- etf |> dplyr::slice_tail(n = 1)
fin_de_mes   <- seq(ultimo_mes$mes, by = "month", length.out = 2)[2] - 1
mes_completo <- ultimo_mes$fecha_cierre >= (fin_de_mes - 4)

if (!mes_completo) {
  message("Se descarta el último mes del ETF (", format(ultimo_mes$mes, "%Y-%m"),
          ") por estar incompleto. Último dato: ", ultimo_mes$fecha_cierre)
  etf <- etf |> dplyr::filter(mes < ultimo_mes$mes)
} else {
  message("El último mes del ETF (", format(ultimo_mes$mes, "%Y-%m"),
          ") está completo y se conserva.")
}
etf <- etf |> dplyr::select(-fecha_cierre)


# ---- 3. Base mensual y construcción de variables --------------------
datos_brutos <- etf |>
  dplyr::inner_join(tpm_cl,    by = "mes") |>
  dplyr::inner_join(tpm_us,    by = "mes") |>
  dplyr::inner_join(inf_cl,    by = "mes") |>
  dplyr::inner_join(inf_us,    by = "mes") |>
  dplyr::inner_join(des_cl,    by = "mes") |>
  dplyr::inner_join(des_us,    by = "mes") |>
  dplyr::inner_join(imacec_cl, by = "mes") |>
  dplyr::inner_join(dolar_cl,  by = "mes") |>
  dplyr::arrange(mes) |>
  dplyr::mutate(
    ret_mes  = (precio_etf / dplyr::lag(precio_etf) - 1) * 100,  # Retorno mes t
    ret_sig  = dplyr::lead(ret_mes),                             # Retorno mes t+1 (Y regresión)
    d_tpm_cl = tpm_cl - dplyr::lag(tpm_cl),                      # Variación mensual TPM Chile
    d_tpm_us = tpm_us - dplyr::lag(tpm_us),                      # Variación mensual TPM EE.UU.
    ret_dolar = (dolar_cl / dplyr::lag(dolar_cl) - 1) * 100,  # Variación mensual USD/CLP (%)
    sube_sig = factor(
      ifelse(ret_sig > 0, "Sube", "Baja"),
      levels = c("Baja", "Sube")   # Nivel 1 = referencia (0), Nivel 2 = clase positiva (1)
    )
  )

# Auditoría de datos faltantes antes de limpiar (para documentar en el informe)
print(colSums(is.na(datos_brutos)))

# Eliminar observaciones con NA generados por lag/lead o inicio de series
datos <- datos_brutos |> tidyr::drop_na()

dplyr::glimpse(datos)
print(range(datos$mes))
print(nrow(datos))


# ---- 4. Análisis exploratorio (EDA) ---------------------------------
print(summary(datos))

# 4.1 Evolución del precio del ETF
g_precio <- ggplot2::ggplot(datos, ggplot2::aes(x = mes, y = precio_etf)) +
  ggplot2::geom_line(color = "steelblue") +
  ggplot2::theme_minimal() +
  ggplot2::labs(
    title = "CFIETFCC: precio de cierre ajustado (fin de mes)",
    x = NULL, y = "CLP"
  )
guardar_grafico(g_precio, "4_1_precio_etf.png")

# 4.2 Distribución del retorno mensual del mes siguiente
g_hist <- ggplot2::ggplot(datos, ggplot2::aes(x = ret_sig)) +
  ggplot2::geom_histogram(bins = 25, fill = "steelblue", color = "white") +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed") +
  ggplot2::theme_minimal() +
  ggplot2::labs(
    title = "Distribución del retorno mensual del ETF",
    x = "Retorno mes siguiente (%)", y = "Frecuencia"
  )
guardar_grafico(g_hist, "4_2_distribucion_retorno.png")

# 4.3 Balance de clases
balance_clases <- datos |>
  dplyr::count(sube_sig) |>
  dplyr::mutate(prop = n / sum(n))
print(balance_clases)

# 4.4 Evolución de variables macroeconómicas (incluye USD/CLP)
g_macro <- datos |>
  dplyr::select(mes, tpm_cl, tpm_us, inf_cl, inf_us, des_cl, des_us, imacec_cl, dolar_cl) |>
  tidyr::pivot_longer(-mes, names_to = "variable", values_to = "valor") |>
  ggplot2::ggplot(ggplot2::aes(x = mes, y = valor)) +
  ggplot2::geom_line(color = "darkorange") +
  ggplot2::facet_wrap(~ variable, scales = "free_y") +
  ggplot2::theme_minimal() +
  ggplot2::labs(
    title = "Variables macroeconómicas (último dato disponible a fin de mes)",
    x = NULL, y = NULL
  )
guardar_grafico(g_macro, "4_4_variables_macro.png", ancho = 10, alto = 7)

# 4.5 Correlación lineal de cada predictor con el retorno del mes siguiente
correlaciones <- datos |>
  dplyr::select(-mes, -precio_etf, -sube_sig) |>
  cor() |>
  as.data.frame() |>
  tibble::rownames_to_column("variable") |>
  dplyr::select(variable, cor_con_Y = ret_sig) |>
  dplyr::filter(variable != "ret_sig") |>
  dplyr::arrange(dplyr::desc(abs(cor_con_Y)))
print(correlaciones)

# 4.6 Boxplot: desempleo en Chile según dirección del ETF
g_box <- ggplot2::ggplot(datos, ggplot2::aes(x = sube_sig, y = des_cl)) +
  ggplot2::geom_boxplot(fill = "lightblue") +
  ggplot2::theme_minimal() +
  ggplot2::labs(
    title = "Desempleo Chile según dirección del ETF el mes siguiente",
    x = NULL, y = "Desempleo (%)"
  )
guardar_grafico(g_box, "4_6_boxplot_desempleo.png")


# ---- 5. Partición CRONOLÓGICA (60% / 20% / 20%) ----------------------
# Series temporales financieras: corte cronológico estricto (sin strata)
# para entrenar con el pasado y evaluar en el futuro sin fuga de datos.
set.seed(123)
particion <- rsample::initial_validation_time_split(datos, prop = c(0.6, 0.2))
entreno   <- rsample::training(particion)
valida    <- rsample::validation(particion)
prueba    <- rsample::testing(particion)

print(purrr::map(
  list(entreno = entreno, valida = valida, prueba = prueba),
  \(d) c(desde = format(min(d$mes)), hasta = format(max(d$mes)), n = nrow(d))
))


# =====================================================================
# PARTE A: REGRESIÓN (Y = ret_sig, numérica)
# =====================================================================
f_reg <- ret_sig ~ tpm_cl + tpm_us + inf_cl + inf_us + des_cl + des_us +
  imacec_cl + d_tpm_cl + d_tpm_us + ret_mes + dolar_cl + ret_dolar

# ---- 6. Especificación de modelos (parsnip) -------------------------
spec_lm <- parsnip::linear_reg() |>
  parsnip::set_engine("lm")

spec_arbol_reg <- parsnip::decision_tree(tree_depth = 3, min_n = 5) |>
  parsnip::set_engine("rpart") |>
  parsnip::set_mode("regression")

spec_rf_reg <- parsnip::rand_forest(trees = 500, min_n = 5) |>
  parsnip::set_engine("ranger", importance = "permutation") |>
  parsnip::set_mode("regression")

# ---- 7. Ajuste en ENTRENAMIENTO -------------------------------------
set.seed(123)
mod_lm        <- spec_lm        |> parsnip::fit(f_reg, data = entreno)
mod_arbol_reg <- spec_arbol_reg |> parsnip::fit(f_reg, data = entreno)
mod_rf_reg    <- spec_rf_reg    |> parsnip::fit(f_reg, data = entreno)

# ---- 8. Comparación en VALIDACIÓN (MAE y RMSE) ----------------------
metricas_reg <- yardstick::metric_set(yardstick::mae, yardstick::rmse)

evaluar_reg <- function(modelo, datos_eval, nombre) {
  stats::predict(modelo, new_data = datos_eval) |>
    dplyr::bind_cols(datos_eval |> dplyr::select(mes, ret_sig)) |>
    metricas_reg(truth = ret_sig, estimate = .pred) |>
    dplyr::mutate(modelo = nombre)
}

evaluar_base_reg <- function(datos_ref, datos_eval) {
  datos_eval |>
    dplyr::mutate(.pred = mean(datos_ref$ret_sig)) |>
    metricas_reg(truth = ret_sig, estimate = .pred) |>
    dplyr::mutate(modelo = "Base (promedio)")
}

comp_val_reg <- dplyr::bind_rows(
  evaluar_base_reg(entreno, valida),
  evaluar_reg(mod_lm,        valida, "Regresión lineal"),
  evaluar_reg(mod_arbol_reg, valida, "Árbol de decisión"),
  evaluar_reg(mod_rf_reg,    valida, "Bosque aleatorio")
) |>
  dplyr::select(modelo, .metric, .estimate) |>
  tidyr::pivot_wider(names_from = .metric, values_from = .estimate) |>
  dplyr::arrange(rmse)

print(comp_val_reg)

# ---- 9. Evaluación final en PRUEBA ----------------------------------
# Reentrenamos con entrenamiento + validación y evaluamos en prueba.
entreno_val <- dplyr::bind_rows(entreno, valida)

set.seed(123)
fin_lm        <- spec_lm        |> parsnip::fit(f_reg, data = entreno_val)
fin_arbol_reg <- spec_arbol_reg |> parsnip::fit(f_reg, data = entreno_val)
fin_rf_reg    <- spec_rf_reg    |> parsnip::fit(f_reg, data = entreno_val)

comp_test_reg <- dplyr::bind_rows(
  evaluar_base_reg(entreno_val, prueba),
  evaluar_reg(fin_lm,        prueba, "Regresión lineal"),
  evaluar_reg(fin_arbol_reg, prueba, "Árbol de decisión"),
  evaluar_reg(fin_rf_reg,    prueba, "Bosque aleatorio")
) |>
  dplyr::select(modelo, .metric, .estimate) |>
  tidyr::pivot_wider(names_from = .metric, values_from = .estimate) |>
  dplyr::arrange(rmse)

print(comp_test_reg)

# Gráfico: retorno real vs. predicho en prueba (Bosque aleatorio)
g_real_pred <- stats::predict(fin_rf_reg, new_data = prueba) |>
  dplyr::bind_cols(prueba |> dplyr::select(mes, ret_sig)) |>
  ggplot2::ggplot(ggplot2::aes(x = mes)) +
  ggplot2::geom_line(ggplot2::aes(y = ret_sig, color = "Real")) +
  ggplot2::geom_line(ggplot2::aes(y = .pred,   color = "Predicho")) +
  ggplot2::geom_point(ggplot2::aes(y = ret_sig, color = "Real")) +
  ggplot2::theme_minimal() +
  ggplot2::labs(
    title = "Retorno mensual del ETF: real vs. predicho (prueba)",
    x = NULL, y = "Retorno (%)", color = NULL
  )
guardar_grafico(g_real_pred, "9_real_vs_predicho_prueba.png")

# ---- 10. Interpretación (asociaciones, no causalidad) ---------------
# Coeficientes de la regresión lineal
print(broom::tidy(fin_lm))

# Importancia de variables del bosque aleatorio (permutación)
g_importancia <- parsnip::extract_fit_engine(fin_rf_reg)$variable.importance |>
  tibble::enframe(name = "variable", value = "importancia") |>
  ggplot2::ggplot(ggplot2::aes(x = importancia, y = reorder(variable, importancia))) +
  ggplot2::geom_col(fill = "steelblue") +
  ggplot2::theme_minimal() +
  ggplot2::labs(
    title = "Importancia de variables – Bosque aleatorio",
    x = "Aumento del error al permutar la variable", y = NULL
  )
guardar_grafico(g_importancia, "10_importancia_variables_rf.png")


# =====================================================================
# PARTE B: CLASIFICACIÓN (Y = sube_sig: "Baja" / "Sube")
# =====================================================================
f_cla <- sube_sig ~ tpm_cl + tpm_us + inf_cl + inf_us + des_cl + des_us +
  imacec_cl + d_tpm_cl + d_tpm_us + ret_mes + dolar_cl + ret_dolar

spec_log <- parsnip::logistic_reg() |>
  parsnip::set_engine("glm")

spec_arbol_cla <- parsnip::decision_tree(tree_depth = 3, min_n = 5) |>
  parsnip::set_engine("rpart") |>
  parsnip::set_mode("classification")

spec_rf_cla <- parsnip::rand_forest(trees = 500, min_n = 5) |>
  parsnip::set_engine("ranger") |>
  parsnip::set_mode("classification")

set.seed(123)
mod_log       <- spec_log       |> parsnip::fit(f_cla, data = entreno)
mod_arbol_cla <- spec_arbol_cla |> parsnip::fit(f_cla, data = entreno)
mod_rf_cla    <- spec_rf_cla    |> parsnip::fit(f_cla, data = entreno)

# Evaluación con "Sube" como 2do nivel (clase positiva -> event_level = "second")
evaluar_cla <- function(pred) {
  dplyr::bind_rows(
    yardstick::accuracy(pred,  truth = sube_sig, estimate = .pred_class),
    yardstick::recall(pred,    truth = sube_sig, estimate = .pred_class, event_level = "second"),
    yardstick::precision(pred, truth = sube_sig, estimate = .pred_class, event_level = "second"),
    yardstick::spec(pred,      truth = sube_sig, estimate = .pred_class, event_level = "second")
  )
}

predecir_cla <- function(modelo, datos_eval) {
  dplyr::bind_cols(
    stats::predict(modelo, new_data = datos_eval, type = "class"),
    stats::predict(modelo, new_data = datos_eval, type = "prob"),
    datos_eval |> dplyr::select(mes, sube_sig)
  )
}

# Línea base sin fuga: predice la clase mayoritaria observada en datos_ref
pred_base_cla <- function(datos_ref, datos_eval) {
  clase_mayoritaria <- datos_ref |>
    dplyr::count(sube_sig, sort = TRUE) |>
    dplyr::slice(1) |>
    dplyr::pull(sube_sig) |>
    as.character()
  
  datos_eval |>
    dplyr::select(mes, sube_sig) |>
    dplyr::mutate(.pred_class = factor(clase_mayoritaria, levels = c("Baja", "Sube")))
}

# ---- 11. Comparación en VALIDACIÓN ----------------------------------
comp_val_cla <- dplyr::bind_rows(
  evaluar_cla(pred_base_cla(entreno, valida))      |> dplyr::mutate(modelo = "Base (clase mayoritaria)"),
  evaluar_cla(predecir_cla(mod_log, valida))       |> dplyr::mutate(modelo = "Regresión logística"),
  evaluar_cla(predecir_cla(mod_arbol_cla, valida)) |> dplyr::mutate(modelo = "Árbol de decisión"),
  evaluar_cla(predecir_cla(mod_rf_cla, valida))    |> dplyr::mutate(modelo = "Bosque aleatorio")
) |>
  dplyr::select(modelo, .metric, .estimate) |>
  tidyr::pivot_wider(names_from = .metric, values_from = .estimate)

print(comp_val_cla)

# ---- 12. Evaluación final en PRUEBA ---------------------------------
set.seed(123)
fin_log       <- spec_log       |> parsnip::fit(f_cla, data = entreno_val)
fin_arbol_cla <- spec_arbol_cla |> parsnip::fit(f_cla, data = entreno_val)
fin_rf_cla    <- spec_rf_cla    |> parsnip::fit(f_cla, data = entreno_val)

pred_test_log   <- predecir_cla(fin_log,       prueba)
pred_test_arbol <- predecir_cla(fin_arbol_cla, prueba)
pred_test_rf    <- predecir_cla(fin_rf_cla,    prueba)

comp_test_cla <- dplyr::bind_rows(
  evaluar_cla(pred_base_cla(entreno_val, prueba)) |> dplyr::mutate(modelo = "Base (clase mayoritaria)"),
  evaluar_cla(pred_test_log)                      |> dplyr::mutate(modelo = "Regresión logística"),
  evaluar_cla(pred_test_arbol)                    |> dplyr::mutate(modelo = "Árbol de decisión"),
  evaluar_cla(pred_test_rf)                       |> dplyr::mutate(modelo = "Bosque aleatorio")
) |>
  dplyr::select(modelo, .metric, .estimate) |>
  tidyr::pivot_wider(names_from = .metric, values_from = .estimate)

print(comp_test_cla)

# Matrices de confusión en prueba
print(yardstick::conf_mat(pred_test_log,   truth = sube_sig, estimate = .pred_class))
print(yardstick::conf_mat(pred_test_arbol, truth = sube_sig, estimate = .pred_class))
print(yardstick::conf_mat(pred_test_rf,    truth = sube_sig, estimate = .pred_class))

# ---- 13. Exportar TODOS los resultados en un solo Excel -------------
# 1. Definir ruta (en R siempre con barra inclinada "/") y crear carpeta si no existe
ruta_salida <- "resultados"
dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)

# 2. Preparar tablas resumen adicionales (coeficientes, importancia, predicciones y matrices)
coeficientes_lm <- broom::tidy(fin_lm)

importancia_rf <- parsnip::extract_fit_engine(fin_rf_reg)$variable.importance |>
  tibble::enframe(name = "variable", value = "importancia") |>
  dplyr::arrange(dplyr::desc(importancia))

pred_test_reg <- stats::predict(fin_rf_reg, new_data = prueba) |>
  dplyr::bind_cols(prueba |> dplyr::select(mes, precio_etf, ret_sig))

matriz_conf_log <- yardstick::conf_mat(pred_test_log, truth = sube_sig, estimate = .pred_class)$table |>
  as.data.frame()

matriz_conf_rf <- yardstick::conf_mat(pred_test_rf, truth = sube_sig, estimate = .pred_class)$table |>
  as.data.frame()

matriz_conf_arbol <- yardstick::conf_mat(
  pred_test_arbol,
  truth = sube_sig,
  estimate = .pred_class
)$table |>
  as.data.frame()

# 3. Armar la lista de hojas (cada elemento será una pestaña del Excel)
lista_resultados <- list(
  Base_Mensual        = datos,
  Val_Regresion       = comp_val_reg,
  Test_Regresion      = comp_test_reg,
  Val_Clasificacion   = comp_val_cla,
  Test_Clasificacion  = comp_test_cla,
  Coeficientes_LM     = coeficientes_lm,
  Importancia_RF      = importancia_rf,
  Pred_Test_Reg       = pred_test_reg,
  Pred_Test_Cla_Log   = pred_test_log,
  Pred_Test_Cla_RF    = pred_test_rf,
  Pred_Test_Cla_Arbol = pred_test_arbol,
  ConfMat_Logistica   = matriz_conf_log,
  ConfMat_Bosque      = matriz_conf_rf,
  ConfMat_Arbol       = matriz_conf_arbol
)

# 4. Exportar todo en un único archivo .xlsx
writexl::write_xlsx(
  lista_resultados,
  path = file.path(ruta_salida, "resultados_TIG_CFIETFCC.xlsx")
)

message("Listo. Resultados en '", ruta_salida, "/' y gráficos en '", dir_graficos, "/'.")