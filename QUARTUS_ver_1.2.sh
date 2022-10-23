#!/bin/bash
# Версия скрипта 1.2 от 24.10.22 00:20
# Переменные цветов
red=$'\e[1;31m'
green=$'\e[1;32m'
yellow=$'\e[1;33m'
blue=$'\e[1;34m'
magenta=$'\e[1;35m'
cyan=$'\e[1;36m'
Color_reset=$'\033[0m'
############################################################
# Описание функций, используемых в скрипте                 #
############################################################
Help () {
############################################################
# Help-функция для помощи пользователю в освоении скрипта  #
############################################################
   echo "Add description of the script functions here."
   echo
   echo "Syntax: scriptTemplate [-g|h|v|V]"
   echo "options:"
   echo "g     Print the GPL license notification."
   echo "h     Print this Help."
   echo "v     Verbose mode."
   echo "V     Print software version and exit."
   echo
}
searching_kaktus_prime () {
	# Проверим нет ли в директории со скриптом конфига с записанными переменными
	# В переменной $0 храниться полный путь до скрипта, который был запущен, включая название
	# Данный конфиг создается, если ранее он не был найден
	echo -e "Please, wait. Searching configuration file for script... "
	if [ -f "$(dirname -- "$0")/config.txt" ]
	then
		source "$(dirname -- "$0")/config.txt"
		directory=$path
		echo "$green""File found!""$Color_reset"
		echo
	else
		echo "$red""Configuration file not found! Damn it! Hmm...going to another plan.""$Color_reset"
		echo
		echo -e "Please, wait. Searching of directory Quartus Prime Pro..."
		# Ищем директорию с установленными версиями QUARTUS PRIME PRO, но не в папке trash и local...
		directory=$(find / -type d -name "intelFPGA_pro" | grep -v ".local")
		# Для будущих запусков сохраняем путь до кактуса в конфиге
		echo "path=$directory" > "$(dirname -- "$0")/config.txt"
		echo
		echo "$yellow""Directory found here: ""$cyan""$directory""$Color_reset"
		echo "$yellow""Saved the path in config file in script directory for future launches...""$Color_reset"
		echo
	fi
	#
	#Ищем последнюю версию кактуса, передавая путь до папки с кактусами...
	echo -n "Checking availible versions and chose newest... "
	# Если присутствует папка, то переходим в папку и запускаем процедуру "launch_and_prog"
	if [ -n "$(ls $directory | grep "22.2")" ] ; then
		echo "$magenta""22.2 version found!""$Color_reset"
		echo
		directory=$(find $directory/22.2/ -type f -name "quartus_pgm" | grep -v "linux64")
	elif [ -n "$(ls $directory | grep "22.1")" ] ; then
		echo "$magenta""22.1 version found!""$Color_reset"
		echo
		directory=$(find $directory/22.1/ -type f -name "quartus_pgm" | grep -v "linux64")
	elif [ -n "$(ls $directory | grep "20.2")" ] ; then
		echo "$magenta""20.2 version found!""$Color_reset"
		echo
		directory=$(find $directory/20.2/ -type f -name "quartus_pgm" | grep -v "linux64")
	elif [ -n "$(ls $directory | grep "18.0")" ] ; then
		echo "$magenta""18.0 version found!""$Color_reset"
		echo
		directory=$(find $directory/18.0/ -type f -name "quartus_pgm" | grep -v "linux64")
	else
		echo "Quartus prime programmer can't found because directory are empty..."
		echo "Please, reinstall Quartus or check directory."
	fi
}
launch_and_prog () {
	# Аргумент $1 - путь до кактуса примы про
	local path=$2
	local programmer=$3
	# Запускаем кактус для вывода списка доступных программаторов
	sudo $1 -l # Путь передан в виде аргумента в процедуру
	echo "$yellow""************************************************************************""$Color_reset"
	echo
	echo "To avoid errors with 'Insufficient port permissions' with Quartus Programmer kill jtagd process and run jtagconfig as root..."
	# Убиваем все процессы jtagd, чтобы из рута установить настройки jtag и избежать ошибки, когда не
	# обнаруживаются программаторы
	sudo killall -9 jtagd
	sudo ${1%/*}/jtagconfig
	echo "************************************************************************"
	# Просто по приколу считываем текущую частоту программатора
	echo "Reading current Jtag clock parameter value for fun :). ""$yellow""Value is: ""$cyan""$(sudo ${1%/*}/jtagconfig --getparam $programmer JtagClock)""$Color_reset"
	echo
	# Устанавливаем частоту в 16 МГц специально под jtag цепи прототипа 32С
	echo "Set programmer clock to 16 MHz if programmer is not USB-Blaster first version..."
	sudo ${1%/*}/jtagconfig --setparam $programmer JtagClock 16M
	# Просто по приколу считываем текущую частоту программатора
	echo
	echo "Reading current Jtag clock parameter value for fun again... ""$yellow""Value is: ""$cyan""$(sudo ${1%/*}/jtagconfig --getparam $programmer JtagClock)""$Color_reset"
	echo "************************************************************************"
	echo
	# Ну и наконец запускаем прошивание цепи и временное логирование
	echo "$magenta""Aaaand finaly we starting programmer...""$Color_reset"
	echo
	rm ./Log.txt
	end=0 
	repeat_counter=0
	echo
	while [ $end == 0 ]
	do		
		sudo stdbuf -o 0 $1 -c $programmer --initcfg $path 2>&1 | tee -a Log.txt
		end=0
		# Проверка на попытки сконфигурровать цепь пять раз (ШО? РУССКИЙ НЕ РОДНОЙ? ШО ЗА ХЕРНЮ НАПИСАЛ?)
		if (( $repeat_counter == 4 ))
		then
			echo
			echo "$red""Tried to repeat the programming several times, but without success. Exit loop...""$Color_rest"
			echo
			echo
			end=1
			repeat_counter=0
		# Если конфигурирование цепи закончилось успешно, то сообщаем и выходим из цикла
		elif grep -Fwq "Quartus Prime Programmer was successful" Log.txt
		then
			echo
			echo "$green""Programming of devices was successful...""$Color_reset"
			echo "$green""************************************************************************""$Color_reset"
			echo "$yellow""-----------------Ended--at--$(date)-----------------""$Color_reset"
			echo
			echo
			end=1
		# При i2c ошибке пробуем еще раз сконфигурировать цепь
		elif grep -Fwq "Error (22248): Detected a PMBUS error during configuration." Log.txt
		then
			echo
			echo "$red""PMBUS error detected. Repeat programming...""$Color_reset"
			echo "$red""************************************************************************""$Color_reset"
			echo
			echo
			end=0
			repeat_counter=$((repeat_counter+1))
		# Если файл нашелся, но он написан коряво и кактус его не принял, то выходим из цикла
		elif grep -Fwq "Error (210008):" Log.txt
		then
			echo
			echo "$red""Chain Description file contains syntax errors. Read messages from Quartus above, check file and try again...""$Color_reset"
			echo "$red""************************************************************************""$Color_reset"
			echo "$yellow""-----------------Ended--at--$(date)-----------------""$Color_reset"
			end=1
		# Если что-то не так с цепью (нет доступа к цепи пока что тут прописано), то пробуем снова.
		elif grep -Fwq "Can't access JTAG chain" Log.txt
		then
			echo
			echo "$red""Can't access JTAG chain. Trying repeat again...""$Color_reset"
			echo "$red""************************************************************************""$Color_reset"
			echo "$yellow""-----------------Ended--at--$(date)-----------------""$Color_reset"
			echo
			echo
			end=0
			repeat_counter=$((repeat_counter+1))
		elif grep -Fwq "Error (213013)" Log.txt
		then
			echo 
			echo "$red""Programming hardware cable not detected. Try again...""$Color_reset"
			echo "$red""************************************************************************""$Color_reset"
			echo "$yellow""-----------------Ended--at--$(date)-----------------""$Color_reset"
			end=1			
		else
			echo
			echo "$red""SHTOTO PROIZOHLO...""$Color_reset"
			echo "$yellow""-----------------Ended--at--$(date)-----------------""$Color_reset"
			echo
			echo
			end=1
		fi
	done
	rm ./Log.txt
	#Return Code Description 
	#0 Execution was successful 
	#2 Execution failed due to an internal error 
	#3 Execution failed due to user error(s) 
	#4 Execution was stopped by the user 
	# Далее надо написать обработчики ошибок, возникших при прошивании цепи в целом или конкретных
	# ПЛИС
}
chk_programmer_number () {
# Цикл проверки введенного номера программатора
	local programmer_number=$1 # Присваем во внутреннюю переменную переданный аргумент
	chk_passed=1
	while [ $chk_passed -ne 0 ]
	do
		if ! [[ "$programmer_number" =~ ^[0-9]+$ ]]
		then
			chk_passed=1
			echo "$red""Entered value ""$yellow""'$programmer_number'""$red"" is not a number. Please enter number of needed programmer again...""$Color_reset"
			read -e -p "Enter number of programmer: " programmer_number

		else 
			chk_passed=0
			echo "For entered number " "$yellow" "$programmer_number" "$green" " ---> Check PASSED!""$Color_reset"
		fi
	done
	# Возвращаем значение переменной
	return $programmer_number
}
check_path_cdf () {
# Цикл проверки пути до *.cdf файла
	cdf_path=$1 # Присваиваем во внутреннюю переменную переданный аргумент
	check_res=1
	while [ $check_res -ne 0 ]
	do
		test -f $cdf_path # Проверка существования файла
		check_res=$? # После завершения команды записываем exit code в переменную
		if [ $check_res -ne 0 ] ; then
			echo "$red""File not found. Please try entering the path again...""$Color_reset"
			# Вставил сюда пока что строку ниже			
			read -e -p "Enter path to *.cdf file for programming: " cdf_path
			echo
		else
			echo "For entered path " "$cyan" "$cdf_path" "$green" " ---> Check PASSED!""$Color_reset"
		fi
	done
}
############################################################
# Основная часть кода начинается тут                       #
############################################################
# Обработка опций, введенных при запуске скрипта
while getopts ":h" option; do
case $option in
	h)
		Help
       	exit;;
esac
done
#############################################################
echo "$yellow""---Started--at--$(date)--------""$Color_reset"
echo "$green""         QUARTUS PROGRAMMER BASH SCRIPT "
echo "***************************************************"
echo "*       CREATED     BY    GREEN_ELEPHANT          *"
echo "***************************************************"		
echo ""
echo "               _.-- ,.--. "
echo "             .'   .'    / "
echo "             | @       |'..--------._ "
echo "            /      \._/              '. "
echo "           /  .-.-                     \ "
echo "          (  /    \                     \ "
echo "           \\      '.                  | # "
echo "            \\       \   -.           / "
echo "             :\       |    )._____.'   \ "
echo '              "       |   /  \  |  \    ) '
echo "                snd   |   |./'  :__ \.-' "
echo "                      '--' "
echo "$Color_reset"
############################################################
# Проверки и идентификации введенных аргументов            #
############################################################
# Определим количество передаваемых аргументов и проверим, что их четное количество. Почему?
# Потому что шаблон таков: [ {путь к 1 cdf-файлу} {номер программатора} {путь к 2 cdf-файлу} 
# {номер программатора}...]. Следовательно, минимальное количество аргументов - 2. 
# Если количество аргументов не кратно 2, то дальнейшее выполнение скрипта бессмысленно.
echo "$magenta""Checking of entered arguments...""$Color_reset"
if [ $# == 0 ] ; then	# Проверка на отсутствие аргументов
	echo "$red""Arguments not entered!""$Color_reset"
	echo "Please run script with entered arguments..."
	exit 0 # Прекращаем дальнешйее выполнение скрипта
elif [ $(($# % 2)) == 0 ] ; then	# Проверка на четность
	echo "$green""The number of entered arguments is correct. Going to next step of checking...""$Color_reset"
	echo
else
	echo "$red""The number of input arguments isn't correct.""$Color_reset"
	echo "Please, check entering arguments and run script again."
	exit 0
fi
declare -a arguments
for i in $@
do
	arguments=( ${arguments[@]} $i ) # Записываем переданные аргументы во временный массив
done
############################################################
# Цикл проверки аргументов с номерами программаторов       #
############################################################
echo "$magenta""Checking entered numbers of programmers...""$Color_reset"
for (( i=0; i < ${#arguments[@]}; ((i=i+2)) ))
do
	chk_programmer_number ${arguments[i+1]} # Запускаем процедуру проверки переменной номера программатора
	arguments[i+1]="$?" # На выходе из процедуры присваиваем значение для случая, если оно изменилось
done
echo
############################################################
# Цикл проверки аргументов с путями до cdf-файлов          #
############################################################
echo "$magenta""Checking entered paths...""$Color_reset"
for (( i=0; i < ${#arguments[@]}; ((i=i+2)) ))
do
	check_path_cdf ${arguments[i]}
	arguments[i]="$cdf_path"
done
echo
####################################################################################################
# Запускаем процедуру поиска директории с установленным профессиональным кактусом примой на машине #
####################################################################################################
searching_kaktus_prime
############################################################
# Запускаем в цикле "пары" последовательно                 #
############################################################
for (( i=0; i < ${#arguments[@]}; ((i=i+2)) ))
do
	echo "$yellow""----------------Started--at--$(date)----------------""$Color_reset"
	echo "$yellow""************************************************************************""$Color_reset"
	echo "$yellow""************************************************************************""$Color_reset"
	launch_and_prog $directory "${arguments[i]}" "${arguments[i+1]}"
done
exit