# elastic_QE

make sure all ur opt.sout and opt.in are prepared 

1. makedata.pl to make ur data files for 00elastic_QE.pl

2. 00elastic_QE.pl to Change atom positions ($random) and boxs ($scale)

3. 01elastic_QE.pl to get stress from 00elastic_QE.pl

4. 02elastic_QE.pl to calculate and output the file elastic_Opt_* 
