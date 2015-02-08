# dmc-netstream

try:
	if not gSTARTED: print( gSTARTED )
except:
	MODULE = "dmc-netstream"
	include: "../DMC-Corona-Library/snakemake/Snakefile"

module_config = {
	"name": "dmc-netstream",
	"module": {
		"dir": "dmc_corona",
		"files": [
			"dmc_netstream.lua"
		],
		"requires": [
			"dmc-corona-boot",
			"DMC-Lua-Library",
			"dmc-objects",
			"dmc-patch",
			"dmc-sockets",
			"dmc-states-mixin"
		]
	},
	"examples": {
		"base_dir": "examples",
		"apps": [
			{
				"exp_dir": "dmc-netstream-basic",
				"requires": []
			}
		]
	},
	"tests": {
		"files": [],
		"requires": []
	}
}

register( "dmc-netstream", module_config )

