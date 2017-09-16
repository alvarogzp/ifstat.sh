#
# Mide el tráfico de las interfaces elegidas
#
#
# Salida por pantalla:
# Primero se muestra el título, compuesto por una línea separadora, otra con las
# interfaces que se están monitorizando (cada una en su columna), otra con la
# leyenda de las columnas (recibido y enviado) y otra separadora para finalizar
# el título.
#
# Después se muestran los datos, con una línea cada actualización. Para cada interfaz
# se muestran los datos enviados y recibidos durante el último intervalo. Todos
# los datos están en bytes, y se acompañan de una letra indicando su múltiplo
# (B para byte, K para kilobyte, M para megabyte, G para gigabyte, T para terabyte)
# siempre en potencias de 1024 bytes.
# Cuando una interfaz siendo monitorizada deja de existir mientras el programa se
# está ejecutando, su columna se muestra vacía, sin número ni múltiplo.
#
# Al pulsar Control+C (o enviar una señal de interrupción), se detiene la monitorización
# y se muestra un breve resumen de actividad de las interfaces monitorizadas durante
# la ejecución. En este resumen, las columnas que antes eran verticales ahora se
# vuelven horizontales (interfaces, y de cada una bytes recibidos y enviados),
# y en las verticales se encuentra el total de bytes intercambiados durante la ejecución,
# la media de intercambio por segundo, y la cantidad de bytes correspondiente al máximo
# y mínimo valor capturado durante la ejecución.
# Se finaliza con una suma de los bytes intercambiados por todas las interfaces,
# recibido y enviado por separado, y todo junto para terminar.
# El resumen acaba mostrando el tiempo que ha durado la monitorización.
#
#
# Nota:
# Este script sólo está probado en bash 4.2.8.
# El intérprete dash(1) (correspondiente al comando /bin/sh en algunos
# sistema) falla al interpretar el script, ya que en este script se usan
# Vectores propios de bash.
#
#
# Licencia:
# GPL, visita: http://www.fsf.org/licenses/gpl para ver el texto legal.
#



# Valores fijos:
VECTOR_MULTIPLOS=("B" "K" "M" "G" "T" "P" "E" "Z" "Y") # Representaciones de los múltiplos (Byte, Kilobyte, Megabyte, Gigabyte, Terabyte, Petabyte, Exabyte, Zettabyte y Yottabyte)
ESCALA_BC="scale=2" # Escala para las divisiones con bc (time no tiene más precisión que 2 decimales)
NANOSEGUNDOS=1000000000 # Nanosegundos que tiene un segundo
FICHEROINTERFACES="/proc/net/dev" # Fichero con información sobre las interfaces
INTERFACES=$(echo $(awk 'BEGIN { FS=":" } /^ *[a-zA-Z0-9]+:/ { print $1 }' $FICHEROINTERFACES)) # Interfaces existentes

# Valores por defecto:
cantidadmaxima=1024 # Cantidad máxima que mostrar en los datos antes de pasar a un múltiplo superior
tiempo=1 # Actualización de los datos (en segundos)
tiempomostrartitulo=60 # Mostrar de nuevo interfaces y columnas (en segundos)
interfaz="" # Interfaces seleccionadas



# Funciones

# Ayuda
uso()
{
	echo "Medidor de tráfico de las interfaces de red."
	echo
	echo "Uso: ifstat-ng.sh [OPCIONES] [interfaces]"
	echo "Opciones:"
	echo "	-h, --help	Muestra esta ayuda y finaliza"
	echo "	-a, --all	Monitoriza todas las interfaces (incluso las no activas)"
	echo "	-b, --bytes	Muestra los bytes intercambiados durante el intervalo,"
	echo "			en lugar de la media por segundo"
	echo "	-t, --title	Indica el intervalo en segundos tras el que mostrar"
	echo "			el nombre de las interfaces de nuevo (por defecto: $tiempomostrartitulo)"
	echo "	-s, --seconds	Tiempo en segundos entre mediciones (por defecto: $tiempo)"
	echo "	-l, --line	Actualiza los datos en la misma línea (desactiva -t)"
	echo "	-d, --date	Muestra la hora al principio de cada línea"
	echo "Parámetros:"
	echo "	interfaces	Interfaces a monitorizar (por defecto: activas)"
	echo
	echo "Muestra la actividad de las interfaces de red indicadas, realizando mediciones a intervalos regulares."
	echo "Los datos se muestran en bytes o en uno de sus múltiplos de 1024 bytes."
	echo "Al finalizar mediante Control+C (o señal de interrupción), muestra un resumen del tiempo de medición, y datos totales en las interfaces."
	echo
	echo "Licencia: GPL		Hecho por: Alvaro GP		Versión 2 (29/08/2011)"
}

# Comprueba si el parámetro $1 es un número entero positivo (devuelve 0 si lo es, 1 si no)
comprobarnumeroenteropositivo()
{
	[[ $1 =~ ^[0-9]+$ ]] # Devuelve la evaluación de la expresión, que será falsa si no es un número
}

# Comprueba si el parámetro $1 es un número (entero o decimal) positivo (devuelve 0 si lo es, 1 si no)
comprobarnumerodecimalpositivo()
{
	[[ $1 =~ ^[0-9]+([.][0-9]+)?$ ]] # Devuelve true si $1 es un número entero y adicionalmente tiene un punto y más números enteros
}

# Comprueba si existe una interfaz (devuelve 0 si existe, 1 si no)
comprobarinterfaz()
{
	[[ $INTERFACES =~ (^| )$1( |$) ]] # Devuelve true si $1 es una de las palabras separadas por espacios de $INTERFACES
}

# Devuelve un tiempo formateado a partir de uno en segundos
formateartiempo()
{
	local tmp=$(echo "$1 * 1000 / 1" | bc) # Convertir a milisegundos y eliminar parte decimal
	local valor=$(($tmp % 1000))"ms" # Milisegundos
	local resto=$(($tmp / 1000)) # Segundos
	if [ $resto -gt 0 ] # Si hay segundos
	then
		tmp=$(($resto % 60)) # Calcular segundos
		if [ $tmp -ne 0 ] # Si los segundos no son cero
		then
			valor=$tmp"s "$valor # Añadir segundos
		fi
		resto=$(($resto / 60)) # Minutos
		if [ $resto -gt 0 ] # Si hay minutos
		then
			tmp=$(($resto % 60)) # Calcular minutos
			if [ $tmp -ne 0 ] # Si los minutos no son cero
			then
				valor=$tmp"m "$valor # Añadir minutos
			fi
			resto=$(($resto / 60)) # Horas
			if [ $resto -gt 0 ] # Si hay horas
			then
				tmp=$(($resto % 24)) # Calcular horas
				if [ $tmp -ne 0 ] # Si las horas no son cero
				then
					valor=$tmp"h "$valor # Añadir horas
				fi
				resto=$(($resto / 24)) # Días
				if [ $resto -gt 0 ] # Si hay días
				then
					tmp=$(($resto % 365)) # Calcular días
					if [ $tmp -ne 0 ] # Si los días no son cero
					then
						valor=$tmp"D "$valor # Añadir días
					fi
					resto=$(($resto / 365)) # Años
					if [ $resto -gt 0 ] # Si hay años
					then
						valor=$resto"A "$valor # Añadir años
					fi
				fi
			fi
		fi
	fi
	echo $valor
}

# Muestra las interfaces y los títulos de las columnas
mostrartitulo()
{
	if [ ! $proximomostrartitulo ] || ([ $proximomostrartitulo != -1 ] && [ $SECONDS -ge $proximomostrartitulo ]) # Si la variable no está definida, o la próxima ejecución no es -1 y los segundos actuales son mayores o igual que el valor de la variable
	then # Mostrar el título
		# LÍNEA DE SEPARACIÓN SUPERIOR
		if [ $opcionhora ] # Si se ha de poner la hora
		then
			echo -n "________" # Dejar hueco para la hora
		fi
		echo -n "|" # Inicio
		printf "_______________|%.0s" $interfaz # Repetir tantas veces como interfaces haya
		echo # Nueva línea
		# LÍNEA DE INTERFACES
		if [ $opcionhora ] # Si se ha de poner la hora
		then
			ponerenmedioizquierda "Hora" 8 # Poner "Hora"
		fi
		echo -n "|" # Inicio
		for in in $interfaz # Recorrer interfaces
		do
			ponerenmedioizquierda "$in" 15 # Poner interfaz
			echo -n "|" # Añadir separador
		done
		echo # Nueva línea
		# LÍNEA DE COLUMNAS
		if [ $opcionhora ] # Si se ha de poner la hora
		then
			echo -n "HH:MM:SS" # Columna
		fi
		echo -n "|" # Inicio
		printf "Recibid·Enviado|%.0s" $interfaz # Repetir por cada interfaz
		echo # Nueva línea
		# LÍNEA DE SEPARACIÓN INFERIOR
		if [ $opcionhora ] # Si se ha de poner la hora
		then
			echo -n "--------" # Dejar hueco para la hora
		fi
		echo -n "|" # Inicio
		printf -- "---------------|%.0s" $interfaz # Repetir por cada interfaz
		echo # Nueva línea
		# SIGUIENTE MUESTRA DEL TÍTULO
		if [ $tiempomostrartitulo == 0 ] # Si es cero no se muestra más el título
		then
			proximomostrartitulo=-1 # No volver a mostrar título
		else
			proximomostrartitulo=$(($SECONDS + $tiempomostrartitulo)) # Calcular nuevo tiempo para mostrar el título
		fi
	fi
}

# Mostrar múltiplos de la cantidad en bytes dada ($1)
multiplos()
{
	declare -i i=0 # Declarar i como entero e iniciar a cero (Byte)
	local valor=$1 # Iniciar valor a los bytes a convertir
	local decimales="0" # Iniciar decimales a cero
	while [ $valor -gt $cantidadmaxima ] # Mientras el valor sea mayor de la cantidad maxima
	do # Pasar al siguiente múltiplo
		decimales=$valor # Para calcular los nuevos decimales
		valor=$(($valor / 1024)) # Calcular nuevo valor
		i+=1 # Incrementar i (representación del múltiplo)
	done
	echo -n $valor # Mostrar parte entera
	if [ $i -gt 0 ] && [ ${valor} -lt 100 ] # Si el índice es mayor que cero y la parte entera menor de 100
	then
		printf ".%.$((3-${#valor}))s" $(printf "%02i" $((($decimales * 100 / 1024 ) % 100 ))) # Mostrar decimales
	fi
	echo ${VECTOR_MULTIPLOS[$i]} # Añadir unidades
}

# Muestra un valor formateado según la configuración ($1 es el valor anterior, $2 el actual y $3 el tiempo transcurrido)
calcularvalor()
{
	if [ $opcionbytes ] || [[ $3 =~ ^[01]$ ]] # Si está activada la opción -b, o si los segundos son 0 o 1
	then
		echo -n $(($2 - $1)) # Diferencia de bytes
	else # Mostrar media por segundo
		echo "($2 - $1) / $3" | bc # Media por segundo
	fi
}

# Pone un texto ($1) en medio de un espacio de $2 caracteres, hacia la derecha cuando no pueda estar exactamente en el medio
ponerenmedioderecha()
{
	local espaciosantes=$(((1 + $2 - ${#1})/2)) # Sumar uno al total, restar la longitud del texto y dividirlo por dos
	local espaciosdespues=$(($2 -${#1} - $espaciosantes)) # Restar al total la longitud del texto y los espacios antes del texto
	for ((sp=$espaciosantes; sp > 0; sp--)) # Recorrer el número de espacios que hay que poner antes
	do
		echo -n " " # Poner un espacio
	done
	echo -n $1 # Poner texto
	for ((sp=$espaciosdespues; sp > 0; sp--)) # Recorrer el número de espacios que hay que poner después
	do
		echo -n " " # Poner un espacio
	done
}

# Pone un texto ($1) en medio de un espacio de $2 caracteres, hacia la izquierda cuando no pueda estar exactamente en el medio
ponerenmedioizquierda()
{
	local espaciosantes=$((($2 - ${#1})/2)) # Restar la longitud del texto y dividirlo por dos
	local espaciosdespues=$(($2 -${#1} - $espaciosantes)) # Restar al total la longitud del texto y los espacios antes del texto
	for ((sp=$espaciosantes; sp > 0; sp--)) # Recorrer el número de espacios que hay que poner antes
	do
		echo -n " " # Poner un espacio
	done
	echo -n $1 # Poner texto
	for ((sp=$espaciosdespues; sp > 0; sp--)) # Recorrer el número de espacios que hay que poner después
	do
		echo -n " " # Poner un espacio
	done
}

# Devuelve los bytes recibidos y enviados de las interfaces elegidas ($interfaz)
interfazrecibidoyenviado()
{ # Cambiar los espacios de separación de interfaces por |
	# Llamada a awk: dobles comillas necesarias para poder incluir la variable del shell $interfaz
	# Se comprueba que el primer numero no este pegado al nombre de la interfaz, en cuyo caso no se leen aparte los bytes recibidos y habria que contar una posicion menos para los bytes enviados
	local vector=($($awk "
		/^ *(${interfaz// /|}):/ {
			numeros = match(\$1, \":[0-9]+\");
			if (numeros > 0) {
				print \$1 \"|\" \$9
			} else {
				print \$1 \$2 \"|\" \$10
			}
		}
	" $FICHEROINTERFACES)) # interfaz:recibido|enviado interfaz2:recibido|enviado...
	if [ ${#vector[@]} != $longitudvector ] # Falta alguna interfaz
	then
		local nuevovector # Vector corregido
		declare -i i=0 # Contador
		declare -i j=0 # Contador del vector antiguo
		for inter in $INTERFACES # Recorrer interfaces actuales
		do
			if [[ $interfaz =~ (^| )$inter( |$) ]] # Si está la interfaz en las interfaces a monitorizar
			then
				if [ $inter == "${vector[$j]%:*}" ] # Extraer interfaz del vector y comprobar si coincide con la interfaz actual
				then
					nuevovector[$i]=${vector[$j]} # Copiar al nuevo vector
					j+=1 # Incrementar contador
				else
					nuevovector[$i]="$inter:-1|-1" # Crear elemento con -1 recibido y enviado
				fi
				i+=1 # Incrementar contador
			fi
		done
		vector=(${nuevovector[@]}) # Copiar nuevo vector al antiguo
	fi
	echo ${vector[@]} # Devolver vector
}

# Devuelve [recibido enviado] a partir de [interfaz:recibido|enviado]
extraerrecibidoyenviado()
{
	local tmp=${1#*:} # Eliminar interfaz (queda recibido|enviado)
	echo ${tmp/|/ } # Convertir | en espacio y devolver
}

# Crea un vector $indice con las posiciones de las interfaces en el orden de $interfaz según salen en la lectura
calcularindices()
{
	declare -i i=0 # Orden de interfaces
	declare -i j=0 # Posición de la interfaz seleccionada
	local puesto=0 # Indica si se ha puesto alguna interfaz seleccionada
	for inter in $INTERFACES # Recorrer interfaces existentes
	do
		j=0 # Iniciar posición a cero
		for int in $interfaz # Recorrer interfaces seleccionadas
		do
			if [ $int == $inter ] # Si las interfaces coindicen
			then
				indice[$j]=$i # La interfaz seleccionada número $j será la número $i
				puesto=1 # Activar puesto
			fi
			j+=1
		done
		if [ $puesto == 1 ] # Si se ha puesto una (o más) interfaz
		then
			i+=1 # Incrementar posición
			puesto=0 # Desactivar bandera
		fi
	done
	longitudvector=$i # La longitud del vector devuelto por 'interfazrecibidoyenviado'
}

# Inicia los vectores $max y $min según el número de interfaces, a cero
iniciarmaxmin()
{
	declare -i i=0 # Iniciar contador
	for in in $interfaz # Recorrer interfaces
	do
		maxr[$i]=-1 # Iniciar máximo recibido
		maxe[$i]=-1 # Iniciar máximo enviado
		minr[$i]=-1 # Iniciar mínimo recibido
		mine[$i]=-1 # Iniciar mínimo enviado
		i+=1 # Incrementar contador
	done
}

# Comprueba si los bytes recibidos ($2) o los enviados ($3) son los máximos o mínimos de la interfaz de índice $1, actualizando $max y $min si fuera necesario
comprobarmaxmin()
{
	if [ $2 -gt ${maxr[$1]} ] # Si los bytes recibidos son mayores que el máximo recibido
	then
		maxr[$1]=$2 # Actualizar máximo recibido
	fi
	if [ $2 -lt ${minr[$1]} ] || [ ${minr[$1]} == -1 ] # Si los bytes recibidos son menores que el mínimo recibido o está por inicializar (-1)
	then
		minr[$1]=$2 # Actualizar mínimo recibido
	fi
	if [ $3 -gt ${maxe[$1]} ] # Si los bytes enviados son mayores que el máximo enviado
	then
		maxe[$1]=$3 # Actualizar máximo enviado
	fi
	if [ $3 -lt ${mine[$1]} ] || [ ${mine[$1]} == -1 ] # Si los bytes enviados son menores que el mínimo enviado o está por inicializar (-1)
	then
		mine[$1]=$3 # Actualizar mínimo enviado
	fi
}

# Bucle principal
bucle()
{
	mostrartitulo
	calcularindices # Crear $indice
	iniciarmaxmin # Crear $max y $min
	declare -i i # Declarar i como entero
	tiemporeal=$tiempo # El primer ciclo la velocidad se calculará en base al tiempo configurado
	dormir=$tiempo # Empezar el primer ciclo durmiendo el tiempo entero
	tiempons=$(echo "$tiempo * $NANOSEGUNDOS / 1" | bc) # Tiempo que dormir en nanosegundos (se usa bc por si fuera decimal, y se divide por 1 para eliminar cualquier resto decimal de bc)
	dormirns=$tiempons # Tiempo que se dormirá en nanosegundos
	# PRIMERA LECTURA
	antes=($(interfazrecibidoyenviado)) # Guardar como vector [interfaz:recibido|enviado, interfaz2:recibido2|enviado2, ...]
	primera=(${antes[@]}) # Guardar también en $primera, para calcular totales
	tiempoanterior=$(date +%s%N) # Iniciar tiempo anterior al actual
	tiempoprimeralectura=$tiempoanterior # Tiempo de inicio
	
	trap "fin" 2 # Captura Control+C
	
	while true
	do
		# DESCANSO
		sleep $dormir
		mostrartitulo
		# INICIO DE LÍNEA
		if [ $opcionlinea ] # Si se ha de mantener la línea
		then
			echo -en "\r" # Añadir retorno de carro
		fi
		if [ $opcionhora ] # Si se ha de indicar la hora
		then
			echo -n $(date +%X) # Mostrar hora
		fi
		echo -n "|" # Iniciar línea
		# LECTURA
		actual=($(interfazrecibidoyenviado)) # Obtener datos de todas las interfaces seleccionadas
		i=0 # Iniciar contador
		for if in $interfaz # Recorrer interfaces
		do
			# INTERPRETACIÓN
			anterior=($(extraerrecibidoyenviado ${antes[${indice[$i]}]})) # Guardar como vector [recibido, enviado]
			ahora=($(extraerrecibidoyenviado ${actual[${indice[$i]}]})) # Guardar como vector [recibido, enviado]
			if [ $ahora == "-1" ] # Si no está la interfaz
			then
				actual[${indice[$i]}]=${antes[${indice[$i]}]} # Mantener el último valor real de la interfaz
				echo -n "       ·       " # Poner 15 espacios
			else
				if [ ${ahora[0]} -lt ${anterior[0]} ] || [ ${ahora[1]} -lt ${anterior[1]} ] # Si el dato actual es menor que el anterior
				then
					local prim=($(extraerrecibidoyenviado ${primera[${indice[$i]}]}))
					primera[${indice[$i]}]="$if:$((${prim[0]} - (${anterior[0]} - ${ahora[0]})))|$((${prim[1]} - (${anterior[1]} - ${ahora[1]})))" # Decrementar primera lo que haya decrementado el valor
				fi
				recibido=$(calcularvalor ${anterior[0]} ${ahora[0]} $tiemporeal) # Calcular bytes recibidos que mostrar
				enviado=$(calcularvalor ${anterior[1]} ${ahora[1]} $tiemporeal) # Calcular bytes enviados que mostrar
				comprobarmaxmin $i $recibido $enviado # Comprobar si son máximos y mínimos, y actualizar $max y $min
				ponerenmedioizquierda $(multiplos $recibido) 7 # Mostrar recibido a la izquierda
				echo -n "·" # Poner separador de recibido y enviado
				ponerenmedioderecha $(multiplos $enviado) 7 # Mostrar enviado a la derecha
			fi
			echo -n "|" # Poner separador de interfaces
			i+=1 # Incrementar contador
		done
		# FIN DE LÍNEA
		if [ ! $opcionlinea ] # Si no se mantiene en la misma línea
		then
			echo # Nueva línea
		fi
		# ALMACENAMIENTO
		antes=(${actual[@]}) # Guardar valor para la próxima vez
		# DURACIÓN
		tiempotmp=$(date +%s%N) # Obtener fecha actual
		tiempociclo=$(($tiempotmp - $tiempoanterior - $dormirns)) # Tiempo de duración del ciclo
		tiempoanterior=$tiempotmp # Actualizar tiempo anterior
		dormirns=$(($tiempons - $tiempociclo)) # Calcular tiempo que se debe dormir, restando el gastado durante la ejecución
		if [ $dormirns -lt 0 ] # Si el tiempo es menor que cero
		then
			dormirns=0
			dormir=0 # Dormir 0
			tiemporeal=$(echo "$ESCALA_BC; $tiempociclo / $NANOSEGUNDOS" | bc) # Ya que no se duerme, el tiempo del ciclo será $tiempociclo
		else
			dormir=$(echo "$ESCALA_BC; $dormirns / $NANOSEGUNDOS" | bc) # Convertir tiempo a segundos
			tiemporeal=$tiempo # Ya que se duerme para que el tiempo del ciclo sea $tiempo, el tiempo real tenderá a $tiempo
		fi
	done
}

# Muestra estadísticas finales
fin()
{
	trap "" 2 # Quitar captura
	echo # Nueva línea (por si la otra no está finalizada)
	echo
	# ÚLTIMA LECTURA
	ultima=($(interfazrecibidoyenviado)) # Guardar datos de las interfaces seleccionadas
	tiempototal=$(echo "scale=3; ($(date +%s%N) - $tiempoprimeralectura) / $NANOSEGUNDOS" | bc) # Tiempo de ejecución (escala 3 para mostrar milisegundos)
	echo "                 | Total |  Media  || Máximo | Mínimo |"
	declare -i sumar=0 # Suma de bytes recibidos
	declare -i sumae=0 # Suma de bytes enviados
	local mxr=-1 # Máximo recibido absoluto
	local mxe=-1 # Máximo enviado absoluto
	local mnr=-1 # Mínimo recibido absoluto
	local mne=-1 # Mínimo enviado absoluto
	declare -i i=0 # Iniciar contador
	for if in $interfaz # Recorrer las interfaces
	do
		primero=($(extraerrecibidoyenviado ${primera[${indice[$i]}]})) # Guardar como vector [recibido, enviado] la primera lectura
		ultimo=($(extraerrecibidoyenviado ${ultima[${indice[$i]}]})) # Guardar como vector [recibido, enviado]
		if [ "$ultimo" == "-1" ] # Si no existe la interfaz
		then
			ultimo=($(extraerrecibidoyenviado ${antes[${indice[$i]}]})) # Usar como valor el último válido
		fi
		recibido=$((${ultimo[0]} - ${primero[0]})) # Bytes recibidos
		enviado=$((${ultimo[1]} - ${primero[1]})) # Bytes enviados
		sumar+=$recibido # Sumar recibido
		sumae+=$enviado # Sumar enviado
		if [ ${maxr[$i]} == -1 ] # Si maxr es -1, el resto también lo serán
		then
			maxr[$i]=0 # Iniciar a cero
			maxe[$i]=0 # Iniciar a cero
			minr[$i]=0 # Iniciar a cero
			mine[$i]=0 # Iniciar a cero
		else # Comparar con absolutos
			if [ ${maxr[$i]} -gt $mxr ] # Si es mayor que el máximo absoluto
			then
				mxr=${maxr[$i]} # Máximo absoluto recibido
			fi
			if [ ${maxe[$i]} -gt $mxe ] # Si es mayor que el máximo absoluto
			then
				mxe=${maxe[$i]} # Máximo absoluto enviado
			fi
				if [ ${minr[$i]} -lt $mnr ] || [ $mnr == -1 ] # Si es menor que el mínimo absoluto o el mínimo es -1
			then
				mnr=${minr[$i]} # Mínimo absoluto recibido
			fi
			if [ ${mine[$i]} -lt $mne ] || [ $mne == -1 ] # Si es menor que el mínimo absoluto o el mínimo es -1
			then
				mne=${mine[$i]} # Mínimo absoluto enviado
			fi
		fi
		echo "$if:"
		printf "        Recibido:%8s%8s/s |%8s %8s\n" $(multiplos $recibido) $(multiplos $(echo "$recibido / $tiempototal" | bc)) $(multiplos ${maxr[$i]}) $(multiplos ${minr[$i]}) # "multiplos" ocupa como mucho 7 espacios
		printf "        Enviado: %8s%8s/s |%8s %8s\n" $(multiplos $enviado) $(multiplos $(echo "$enviado / $tiempototal" | bc)) $(multiplos ${maxe[$i]}) $(multiplos ${mine[$i]})
		i+=1 # Incrementar contador
	done
	echo
	local suma=$(($sumar + $sumae)) # Total
	local mx=-1 # Máximo
	local mn=-1 # Mínimo
	if [ $mxr == -1 ] # Si mxr es -1, el resto también lo es
	then
		mxr=0 # Iniciar a cero
		mxe=0 # Iniciar a cero
		mnr=0 # Iniciar a cero
		mne=0 # Iniciar a cero
		mx=0 # Iniciar a cero
		mn=0 # Iniciar a cero
	else
		mx=$mxr # Iniciar máximo al recibido
		if [ $mxe -gt $mx ] # Si el enviado es mayor
		then
			mx=$mxe # Asignar máximo al enviado
		fi
		mn=$mnr # Iniciar mínimo al recibido
		if [ $mne -lt $mn ] # Si el enviado es menor
		then
			mn=$mne # Asignar mínimo al enviado
		fi
	fi
	echo "<Total>:"
	printf "        Recibido:%8s%8s/s |%8s %8s\n" $(multiplos $sumar) $(multiplos $(echo "$sumar / $tiempototal" | bc)) $(multiplos $mxr) $(multiplos $mnr)
	printf "        Enviado: %8s%8s/s |%8s %8s\n" $(multiplos $sumae) $(multiplos $(echo "$sumae / $tiempototal" | bc)) $(multiplos $mxe) $(multiplos $mne)
	echo
	printf "        <Ambos>: %8s%8s/s |%8s %8s\n" $(multiplos $suma) $(multiplos $(echo "$suma / $tiempototal" | bc)) $(multiplos $mx) $(multiplos $mn)
	echo
	echo "Tiempo total:     $(formateartiempo $tiempototal)" # Mostrar tiempo
	exit # Salir
}



# Buscar mawk
which mawk > /dev/null 2> /dev/null # Buscar "mawk" (más rápido que "gawk", el "awk" por defecto)
if [ $? == 0 ] # mawk encontrado
then
	awk="mawk" # Usar mawk
else # No mawk encontrado
	awk="awk" # Usar el awk que haya
fi

# Comprobar opciones
while [ $# -gt 0 ] # Mientras queden parámetros
do
	case $1 in # Determinar opción
		-h | --help ) # Ayuda
			uso
			exit # Salir
			;;
		-a | --all ) # Todas las interfaces
			interfaz=$INTERFACES # Añadir todas las interfaces
			;;
		-b | --bytes ) # Mostrar datos intercambiados, sin media
			opcionbytes=1 # Crear variable
			;;
		-t | --title ) # Tiempo de actualización del título
			if comprobarnumeroenteropositivo $2 # Si es número
			then
				tiempomostrartitulo=$2 # Asignar tiempo
			else
				echo "La opción '$1' necesita como argumento un número entero positivo" >&2 # Avisar
				exit 1 # Salir con error
			fi
			shift # Pasar el valor
			;;
		-s | --seconds ) # Segundos de actualización
			if comprobarnumerodecimalpositivo $2 # Si es número incluso decimal
			then
				tiempo=$2 # Asignar tiempo
			else
				echo "La opción '$1' necesita un número entero (o decimal) positivo como argumento" >&2 # Avisar
				exit 1 # Salir con error
			fi
			shift # Pasar el parámetro
			;;
		-l | --line ) # Actualizar en la misma línea
			opcionlinea=1 # Crear variable
			tiempomostrartitulo=0 # No mostrar repetidas veces el título
			;;
		-d | --date ) # Mostrar hora
			opcionhora=1 # Crear variable
			;;
		* ) # Otro valor (interfaz)
			interfaz+=" " # Añadir el espacio, para saber que se indicó interfaz
			if comprobarinterfaz $1 # Comprobar si existe la interfaz
			then
				interfaz+=$1 # Añadir interfaz
			else
				ponerenmedioderecha $1 16 >&2 # Nombre de la interfaz
				echo "| Interfaz no reconocida" >&2 # Avisar
			fi
			;;
	esac
	shift # Pasar al siguiente parámetro
done

if [ ! "$interfaz" ] # Si no se ha indicado interfaz
then
	interfaz=$(ifconfig -s | $awk 'BEGIN { getline } { print $1 }') # Obtener interfaces activas
fi
interfaz=$(echo $interfaz) # Eliminar espacios sobrantes y saltos de línea
if [ ! "$interfaz" ] # Si no hay interfaz tras eliminar espacios sobrantes
then
	echo "Saliendo: No hay interfaces que monitorizar" >&2 # Avisar
	exit 2 # Salir con error
fi



# Inicio
bucle

