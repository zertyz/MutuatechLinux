ArrayPiCalc
=[[

Device Write Block Size == velocidade e previne desgaste desnecessário --> usar o maior block size entre os devices (priorizar não desgastar sobre a velocidade do conjunto)

	Requisitos:
		1) partições devem ser alinhadas pelo block size e ter números inteiros de block size. Exceto, talvez, para a partição boot do SD Card

Parâmetros:
	1) Número de devices                                       -- nDevices
	2) Número de setores (512 bytes) de cada device            -- deviceSectors
	3) Block Size do Conjunto (maior entre todos os devices)   -- arrayBlockSizeKb
	4) Total de Swap desejado                                  -- desiredSwapSizeKb
	5) Tamanho min da partição boot do device sdcard (35768kb) -- bootPartitionMinSizeKb

Programa deve calcular as partições apropriadas para RAID0, Swap e Boot, respeitando as entradas acima, levando em conta as prioridades a seguir:
	1) Não disperdiçar nenhum byte -- todas as partições RAID0 devem ter o mesmo tamanho
	2) Não desgastar desnecessariamente os devices -- respeitar o requisito 1, incluindo readequações para cima da partição boot
	3) Performance


Normalizando os números,
	a) número de setores do device sd card deve ter descontado o tamanho mínimo da partição boot -- setores final de boot = 1 + bootPartitionMinSizeKb*2 -- alinhado com arrayBlockSizeKb
]]


nDevices=5
deviceNames={"sdb", "sdc", "sdd", "sde", "sdf"}
deviceSectors={sdb=15353856, sdc=3915776, sdd=7831552, sde=3907583, sdf=7884800}
-- readSpeeds (MiB/sec) -- infer with sudo dd if=/dev/sdX of=/dev/null bs=$((4096*1024)) status=progress
deviceReadSpeeds={sdb=17.8, sdc=19.2, sdd=18.0, sde=27.7, sdf=28.5}
-- writeSpeeds (MiB/sec) -- infer with sudo dd if=/dev/zero of=/dev/sdX bs=$((64*1024)) count=$((16*128)) oflag=sync status=progress
deviceWriteSpeeds={sdb=6.7, sdc=7.5, sdd=3.4, sde=8.0, sdf=17.0}

arrayBlockSizeKb=64
arrayBlockSizeSectors=64*2
desiredSwapSizeKb=384*1024
bootPartitionMinSizeKb=32768

function getBlocks()
	local bootBlocks=math.ceil((1+(bootPartitionMinSizeKb*2))/arrayBlockSizeSectors)
	print("\tboot partition blocks: "..bootBlocks)
	print("\t\tsdcard first data sector: "..(bootBlocks*arrayBlockSizeSectors))
	print("\t\tsdcard boot partition: from sector 1 to "..((bootBlocks*arrayBlockSizeSectors)-1))
	local isSDCard=true
	for i, deviceName in ipairs(deviceNames) do
		local blocks=math.floor(deviceSectors[deviceName] / arrayBlockSizeSectors)
		if (isSDCard) then
			blocks=blocks.." (corrected, due to boot partition restrictions to "..(blocks-bootBlocks)..")"
			isSDCard=false
		end
		print('\t'..deviceName..": "..blocks)
	end
end

print("Device Blocks:")
getBlocks()

-- partições:
-- sdb: 4 partições de dados
-- sdc: 1 partição
-- sdd: 2 partições
-- sde: 1 partição de dados com 29637 blocos -- 3793536 setores
-- sdf: 2 partições
-- (elas devem começar no setor 128 -- ou múltiplo de 128)

--      sdb: 891
--      sdc: 955
--      sdd: 1910
-- swap sde: 890 blocks
--      sdf: 2326
-- total: 435 Megas -- OK!!
-- porém vai se perder 64k em cada partição de swap por questões de alinhamento

-- b1 c1 b2 d1 f1 b3 e1 b4 d2 f2

-- Here goes some thing similar to a process:
-- 1) run get blocks to get each device size
-- 2) run the following interactive process:
-- > function dv(dev,n,d,s) print(dev..": gets "..((n-s)/(d)).." partitions of "..(d).." blocks") end
-- > s=890 dv("sdb", 119439, 30527-s, s+1) dv("sdc", 30592, 30527-s, s+65) dv("sdd", 61184, 30527-s, s+1020) dv("sde", 30527, 30527-s, s) dv("sdf", 61600, 30527-s, s+1436)
-- sdb: gets 4.0 partitions of 29637 blocks
-- sdc: gets 1.0 partitions of 29637 blocks
-- sdd: gets 2.0 partitions of 29637 blocks
-- sde: gets 1.0 partitions of 29637 blocks
-- sdf: gets 2.0 partitions of 29637 blocks
-- --> the objective here is to find the integer number of partitions on each device, which must have a specific number of 64k (arrayBlockSizeKb) blocks
-- --> for that, adjustments on the number of 64k blocks the swap partition of the smallest device may be made (the s variable) as well as specific additional
-- --> 64l blocks for the other devices (the s+xxx occurrences).
--
-- On the case presented above, the performance of a parallel raid0 was very good for reading, but very poor for writing, because excessive parallel writes were made
-- to the same device (which has 4 partitions) and it wasn't very fast for writes... also, 2 parallel writes for another device brutally slow also contributed for the
-- poor performance.
-- The solution was to create a linear array. But we could do better than that if we put the slowest devices in 2 linear arranges of 5 device each, and make these two
-- linear raids arrange into a parallel raid with only two devices. That said write speeds became 10x faster and read also increased -- ~25%.