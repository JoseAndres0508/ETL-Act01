# -*- coding: utf-8 -*-
"""
ISW-623 Actividad 1 - Generador de datos de prueba (Persona 2)

Genera en DatosEntrada/:
  - PADRON_COMPLETO.txt : padrón SINTÉTICO con el formato del TSE
                          (8 campos separados por coma, campos de texto
                          rellenados con espacios, ANSI 1252, CRLF).
  - distelec.txt        : catálogo real del TSE (copia en
                          Herramientas/distelec_TSE_original.txt) más
                          4 líneas de prueba con errores al final.
y en Documentacion/:
  - Matriz_Casos_Prueba.csv : un renglón por caso especial con el
                              resultado esperado (lo usa Persona 5).

Es determinista (semilla fija): ejecutarlo de nuevo produce los mismos
archivos. Uso:  python Generar_DatosPrueba.py
"""
import csv
import os
import random
from datetime import date, timedelta

SEMILLA = 623
CANT_VALIDOS = 1000           # registros válidos "normales"
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENTRADA = os.path.join(BASE, "DatosEntrada")
DOC = os.path.join(BASE, "Documentacion")
CAT_ORIGINAL = os.path.join(BASE, "Herramientas", "distelec_TSE_original.txt")

rnd = random.Random(SEMILLA)

NOMBRES = ["MARIA", "JOSE", "ANA", "LUIS", "CARLOS", "LAURA", "JUAN", "SOFIA",
           "DANIEL", "VALERIA", "ANDRES", "GABRIELA", "DIEGO", "CAMILA", "PABLO",
           "MARIANA", "JORGE", "FERNANDA", "RICARDO", "PAOLA", "ESTEBAN",
           "NATALIA", "MAURICIO", "ANDREA", "SEBASTIAN", "MONICA", "ALONSO",
           "KARLA", "FABIAN", "SILVIA", "MARIA JOSE", "JUAN CARLOS",
           "ANA LUCIA", "JOSE PABLO", "LUIS DIEGO"]
APELLIDOS = ["RODRIGUEZ", "VARGAS", "JIMENEZ", "MORA", "ROJAS", "GONZALEZ",
             "HERNANDEZ", "CASTRO", "ARAYA", "SOLANO", "ALVARADO", "CHAVES",
             "QUESADA", "RAMIREZ", "CALDERON", "SALAZAR", "CAMPOS", "MURILLO",
             "VILLALOBOS", "SEGURA", "ARIAS", "BRENES", "UMAÑA", "MUÑOZ",
             "NUÑEZ", "ACUÑA", "PEÑA", "OREAMUNO", "BOLAÑOS", "SOTO"]


def leer_catalogo():
    with open(CAT_ORIGINAL, "rb") as f:
        lineas = [l for l in f.read().decode("cp1252").split("\r\n") if l]
    return lineas, [l.split(",", 1)[0] for l in lineas]


def linea_padron(ced, cod, rell, fecha, junta, nom, ap1, ap2):
    """Arma una línea con los anchos del TSE: NOMBRE 30, apellidos 26."""
    return ",".join([ced, cod, rell, fecha, junta,
                     nom.ljust(30), ap1.ljust(26), ap2.ljust(26)])


def fecha_aleatoria():
    d = date(2026, 1, 1) + timedelta(days=rnd.randint(0, 3650))
    return d.strftime("%Y%m%d")


def main():
    cat_lineas, codigos = leer_catalogo()
    usadas = set()

    def cedula_nueva():
        while True:
            c = str(rnd.randint(1, 9)) + "".join(str(rnd.randint(0, 9)) for _ in range(8))
            if c not in usadas:
                usadas.add(c)
                return c

    def junta():
        return str(rnd.randint(1, 7000)).zfill(5)

    # ---------------- 1. Registros válidos normales ----------------
    normales = []
    for _ in range(CANT_VALIDOS):
        normales.append([cedula_nueva(), rnd.choice(codigos), " ", fecha_aleatoria(),
                         junta(), rnd.choice(NOMBRES), rnd.choice(APELLIDOS),
                         rnd.choice(APELLIDOS)])

    # ---------------- 2. Casos especiales del padrón ----------------
    # (id, descripción, campos crudos o línea cruda, esperado, motivo, RF)
    C = []

    def caso(desc, campos, esperado, motivo, rf, cruda=None):
        C.append({"desc": desc, "campos": campos, "cruda": cruda,
                  "esperado": esperado, "motivo": motivo, "rf": rf})

    cod_ok = "101001"
    # Válidos especiales
    caso("Cédula con cero inicial (debe conservarse como texto)",
         ["012345678", cod_ok, " ", "20300115", "00001", "ANA", "SOLANO", "MORA"],
         "Cargado", "", "RF-01, RF-04")
    usadas.add("012345678")
    caso("Espacios sobrantes en cédula, nombre y apellidos",
         ["  203456781 ", "201001", " ", "20310520", "00002", "   LUIS   ", "  ARAYA", " CASTRO "],
         "Cargado", "", "RF-03")
    usadas.add("203456781")
    caso("Código electoral con espacios alrededor",
         ["304567892", " 301001 ", " ", "20290310", "00003", "LAURA", "QUESADA", "ROJAS"],
         "Cargado", "", "RF-03, RF-06")
    usadas.add("304567892")
    caso("Sin segundo apellido (Apellido2 vacío -> NULL)",
         ["405678913", "401001", " ", "20320801", "00004", "JOHN", "SMITH", ""],
         "Cargado", "", "RF-03")
    usadas.add("405678913")
    caso("Ñ en apellidos (página de códigos 1252)",
         ["506789124", "501001", " ", "20330228", "00005", "PEÑA", "MUÑOZ", "NUÑEZ"],
         "Cargado", "", "RF-01")
    usadas.add("506789124")
    caso("Fecha 29 de febrero en año bisiesto (2028)",
         ["607891235", "601001", " ", "20280229", "00006", "SOFIA", "ARIAS", "BRENES"],
         "Cargado", "", "RF-05")
    usadas.add("607891235")
    caso("RELLENO con un valor distinto de espacio (se conserva tal cual)",
         ["708912346", "701001", "X", "20341111", "00007", "PABLO", "SOTO", "CAMPOS"],
         "Cargado", "", "RF-01")
    usadas.add("708912346")
    caso("Distrito de consulado (código 8xxxxx existe en el catálogo)",
         ["109123457", codigos[-1], " ", "20300909", "09999", "DIEGO", "SEGURA", "MORA"],
         "Cargado", "", "RF-06, RF-07")
    usadas.add("109123457")

    # Rechazos por cédula
    caso("Cédula vacía (9 espacios)",
         ["         ", cod_ok, " ", "20300101", "00010", "MARTA", "VARGAS", "MORA"],
         "Rechazado", "CEDULA_VACIA", "RF-04")
    caso("Cédula vacía (campo sin caracteres)",
         ["", cod_ok, " ", "20300101", "00011", "ROSA", "VARGAS", "MORA"],
         "Rechazado", "CEDULA_VACIA", "RF-04")
    caso("Cédula de 8 dígitos",
         ["12345678", cod_ok, " ", "20300101", "00012", "PEDRO", "MORA", "SOTO"],
         "Rechazado", "CEDULA_LONGITUD", "RF-04")
    caso("Cédula de 10 dígitos",
         ["1234567890", cod_ok, " ", "20300101", "00013", "PEDRO", "MORA", "ARIAS"],
         "Rechazado", "CEDULA_LONGITUD", "RF-04")
    caso("Cédula con letra",
         ["1234A6789", cod_ok, " ", "20300101", "00014", "ELENA", "ROJAS", "SOTO"],
         "Rechazado", "CEDULA_CARACTERES", "RF-04")
    caso("Cédula con guiones (9 caracteres)",
         ["1-234-567", cod_ok, " ", "20300101", "00015", "RAUL", "ROJAS", "MORA"],
         "Rechazado", "CEDULA_CARACTERES", "RF-04")
    caso("Cédula con espacio interno",
         ["1234 6789", cod_ok, " ", "20300101", "00016", "IRENE", "CHAVES", "MORA"],
         "Rechazado", "CEDULA_CARACTERES", "RF-04")

    # Rechazos por fecha
    caso("Fecha 31 de febrero (día inexistente)",
         ["811111111", cod_ok, " ", "20300231", "00020", "HUGO", "CASTRO", "MORA"],
         "Rechazado", "FECHA_INVALIDA", "RF-05")
    caso("Fecha con mes 13",
         ["811111112", cod_ok, " ", "20301301", "00021", "OSCAR", "CASTRO", "SOTO"],
         "Rechazado", "FECHA_INVALIDA", "RF-05")
    caso("Fecha con letras",
         ["811111113", cod_ok, " ", "2030AB01", "00022", "IVAN", "ARAYA", "SOTO"],
         "Rechazado", "FECHA_INVALIDA", "RF-05")
    caso("Fecha vacía",
         ["811111114", cod_ok, " ", "        ", "00023", "EDGAR", "ARAYA", "MORA"],
         "Rechazado", "FECHA_INVALIDA", "RF-05")
    caso("Fecha en orden DDMMAAAA (no AAAAMMDD)",
         ["811111115", cod_ok, " ", "15012030", "00024", "TERESA", "SOLANO", "ARIAS"],
         "Rechazado", "FECHA_INVALIDA", "RF-05")
    caso("29 de febrero en año no bisiesto (2027)",
         ["811111116", cod_ok, " ", "20270229", "00025", "GLORIA", "SOLANO", "MORA"],
         "Rechazado", "FECHA_INVALIDA", "RF-05")
    caso("Fecha de 7 dígitos",
         ["811111117", cod_ok, " ", "2030011", "00026", "MARCO", "SOLANO", "SOTO"],
         "Rechazado", "FECHA_INVALIDA", "RF-05")

    # Rechazos por código electoral
    caso("Código electoral que no existe en el catálogo",
         ["821111111", "999999", " ", "20300101", "00030", "ALBERTO", "MORA", "MORA"],
         "Rechazado", "CODELEC_NO_EXISTE", "RF-06")
    caso("Código electoral de 5 dígitos",
         ["821111112", "10100", " ", "20300101", "00031", "BEATRIZ", "MORA", "SOTO"],
         "Rechazado", "CODELEC_NO_EXISTE", "RF-06")
    caso("Código electoral vacío",
         ["821111113", "      ", " ", "20300101", "00032", "CLARA", "MORA", "ARIAS"],
         "Rechazado", "CODELEC_NO_EXISTE", "RF-06")
    caso("Código electoral rechazado en el catálogo (901001 sin provincia)",
         ["821111114", "901001", " ", "20300101", "00033", "DORA", "MORA", "BRENES"],
         "Rechazado", "CODELEC_NO_EXISTE", "RF-06")

    # Varios errores en el mismo registro: gana el primero en orden de validación
    caso("Dos errores: cédula vacía y fecha inválida (gana la cédula)",
         ["         ", cod_ok, " ", "20301301", "00040", "ERNESTO", "SOTO", "MORA"],
         "Rechazado", "CEDULA_VACIA", "RF-04, RF-05")
    caso("Dos errores: fecha inválida y código inexistente (gana la fecha)",
         ["831111111", "999999", " ", "20300231", "00041", "FLOR", "SOTO", "ARIAS"],
         "Rechazado", "FECHA_INVALIDA", "RF-05, RF-06")

    # Líneas mal formadas
    caso("Línea con solo 5 columnas",
         None, "Rechazado", "LINEA_MALFORMADA", "RF-01",
         cruda="841111111,101001, ,20300101,00050")
    caso("Línea con nombre y primer apellido vacíos",
         ["841111112", cod_ok, " ", "20300101", "00051", "", "", ""],
         "Rechazado", "LINEA_MALFORMADA", "RF-01")

    # Duplicados: se insertan al FINAL, la primera aparición es un válido normal
    dup1 = normales[10]
    caso("Cédula repetida con otros datos (la primera aparición se carga)",
         [dup1[0], "102001", " ", "20350101", "00060", "OTRO", "NOMBRE", "DISTINTO"],
         "Rechazado", "CEDULA_DUPLICADA", "Regla de duplicados")
    dup2 = normales[20]
    caso("Línea idéntica repetida",
         list(dup2), "Rechazado", "CEDULA_DUPLICADA", "Regla de duplicados")

    # ---------------- 3. Orden de las líneas ----------------
    # Especiales repartidos entre los normales (excepto los duplicados, al final)
    especiales = [c for c in C if c["motivo"] != "CEDULA_DUPLICADA"]
    duplicados = [c for c in C if c["motivo"] == "CEDULA_DUPLICADA"]
    filas = [("N", n) for n in normales]
    posiciones = sorted(rnd.sample(range(50, len(filas)), len(especiales)), reverse=True)
    for pos, c in zip(posiciones, reversed(especiales)):
        filas.insert(pos, ("E", c))
    filas += [("E", c) for c in duplicados]

    lineas = []
    for i, (tipo, x) in enumerate(filas, start=1):
        if tipo == "N":
            lineas.append(linea_padron(*x))
        else:
            x["linea"] = i
            lineas.append(x["cruda"] if x["cruda"] else linea_padron(*x["campos"]))
            x["texto"] = lineas[-1]

    with open(os.path.join(ENTRADA, "PADRON_COMPLETO.txt"), "wb") as f:
        f.write(("\r\n".join(lineas) + "\r\n").encode("cp1252"))

    # ---------------- 4. Catálogo: original + casos de prueba ----------------
    cat_casos = [
        ("Código de 5 dígitos", "10100,SAN JOSE,CENTRAL,PRUEBA CODIGO CORTO", "CATALOGO_INVALIDO"),
        ("Provincia vacía", "901001,,CENTRAL,PRUEBA SIN PROVINCIA", "CATALOGO_INVALIDO"),
        ("Código con letra", "90A001,SAN JOSE,CENTRAL,PRUEBA CODIGO LETRA", "CATALOGO_INVALIDO"),
        ("Código repetido (101001 ya existe)", "101001,SAN JOSE,CENTRAL,HOSPITAL DUPLICADO", "CATALOGO_DUPLICADO"),
    ]
    cat_final = cat_lineas + [t.ljust(80) for _, t, _ in cat_casos]
    with open(os.path.join(ENTRADA, "distelec.txt"), "wb") as f:
        f.write(("\r\n".join(cat_final) + "\r\n").encode("cp1252"))

    # ---------------- 5. Matriz de casos (CSV) ----------------
    with open(os.path.join(DOC, "Matriz_Casos_Prueba.csv"), "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["Id", "Archivo", "Linea", "Caso", "RF", "Registro",
                    "Resultado esperado", "Motivo esperado"])
        n = 0
        for c in C:
            n += 1
            w.writerow([f"P{n:02d}", "PADRON_COMPLETO.txt", c["linea"], c["desc"], c["rf"],
                        c["texto"].rstrip(), c["esperado"], c["motivo"]])
        base = len(cat_lineas)
        for k, (d, t, m) in enumerate(cat_casos, start=1):
            w.writerow([f"C{k:02d}", "distelec.txt", base + k, d, "RF-02, RF-03", t,
                        "Rechazado", m])

    # ---------------- 6. Resumen ----------------
    rech = {}
    for c in C:
        if c["esperado"] == "Rechazado":
            rech[c["motivo"]] = rech.get(c["motivo"], 0) + 1
    cargados = len(lineas) - sum(rech.values())
    print(f"Padrón: {len(lineas)} leídos, {cargados} cargados, {sum(rech.values())} rechazados")
    for k in sorted(rech):
        print(f"   {k}: {rech[k]}")
    print(f"Catálogo: {len(cat_final)} leídos, {len(cat_lineas)} cargados, {len(cat_casos)} rechazados")


if __name__ == "__main__":
    main()
