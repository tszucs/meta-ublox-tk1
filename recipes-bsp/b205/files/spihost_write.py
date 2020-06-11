#!/usr/bin/python
import sys, getopt, os, time
#from spi import *
import spidev, array


# tegra114: 3175100 Hz <= speed <= 25 MHz
def download ( filename, speed=5000000, chunksize=32 ):
	try:
		with open(filename, 'rb') as filein:
			data = filein.read ()
			data = array.array('B', data).tolist()
	except IOError:
		print "ERROR: Could not open file {0}".format(os.path.basename(filename))
		exit (1)

	try:
#		spi2mars = SPI("/dev/spidev0.0")
#		spi2mars.mode = SPI.MODE_0
#		spi2mars.bits_per_word = 8
#		spi2mars.speed = speed

		spi2mars = spidev.SpiDev()
		spi2mars.open(0,0)
		spi2mars.mode = 0
		spi2mars.max_speed_hz = speed

		startTime = time.time()
		i = 0
		length = len(data)
		while length > chunksize:
#			spi2mars.write(data[i:i+chunksize])
			spi2mars.xfer(data[i:i+chunksize])
			i += chunksize
			length -= chunksize
#		spi2mars.write(data[i:])
		spi2mars.xfer(data[i:])

		stopTime = time.time()
		spi2mars.close()

		print "File {0} dumped on SPI @{1}MHz ({2}bytes in {3} seconds)".format(os.path.basename(filename), speed/1.0e6, len(data), stopTime - startTime)
		return (len(data), stopTime-startTime)
	except Exception, e :
		print "ERROR: SPI Write -", e
		exit (1)


def main (argv):
	print "SAF5100 SPI downloader"
	try:
		opts, args = getopt.getopt(argv, "hf:",["--firmware="])
	except:
		print "spi_host_write.py -f <firmware>"
		sys.exit(2)

	fname="/lib/firmware/cohda/SDRMK5Dual.bin".format(os.path.dirname(sys.argv[0]))

	for opt, arg in opts:
		if opt=="-h":
			print "spi_host_write.py -f <firmware>"
		elif opt=="-f":
			fname = arg

	print "Downloading {0}".format(fname)
	download (fname)


if __name__ == "__main__":
	main (sys.argv[1:])
