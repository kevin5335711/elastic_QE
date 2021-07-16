use strict;
use warnings;
use Cwd;
#########################################Set################################################
my $currentPath = getcwd();
my $slurmbatch = "QE_slurmEla.sh"; #slurm filename
my $QE_path = "/opt/QEGCC_MPICH3.3.2/bin/pw.x";
my $changebox = "Changebox.in";
my @myelement = sort ("Co","Cr","Fe","Hf","Mn","Nb","Ni","Ta","Ti","Zr");
my $myelement = join('',@myelement);



my $Opt_data = `find $currentPath/$myelement/Opt -maxdepth 2 -name "Opt-*-*.data"`;
my @Opt_data = split("\n",$Opt_data);
@Opt_data = sort @Opt_data;
my @filename =  map (($_ =~ m/(\w+.\w+).data$/gm),@Opt_data);
my @element = map (($_ =~ m/^\w+-(\w+)$/gm),@filename);


my $running = `squeue -o \%j | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}

my $scale = 1.0e-3;
my $random = 1.0e-3;
for my $id (0..$#filename){






    my $foldername = "$currentPath/$myelement/Opt/Opt-$filename[$id]/elastic";
    my @ele = split("([A-Z][a-z])",$element[$id]);
    @ele = map (($_ =~ m/([A-Z][a-z])/gm),@ele);

    if (-e "$foldername/Chg+1-$filename[$id].in"){
        next;
    }

    `mkdir -p $foldername`;
    `cp $currentPath/$myelement/Opt/Opt-$filename[$id]/Opt-$filename[$id].in $foldername/$changebox`;

    `sed -i 's:calculation.*:calculation = "relax":'  $foldername/$changebox` ;
    `sed -i '/!ionsend/,/!cellend/{/!ionsend/!{/!cellend/!d}}' $foldername/$changebox`;
    `sed -i '/ATOMIC_POSITIONS {angstrom}/,/CELL_PARAMETERS {angstrom}/{/ATOMIC_POSITIONS {angstrom}/!{/CELL_PARAMETERS {angstrom}/!d}}' $foldername/$changebox`;
    `sed -i '/CELL_PARAMETERS {angstrom}/,/!End/{/CELL_PARAMETERS {angstrom}/!{/!End/!d}}' $foldername/$changebox`;
    my $lx;
    my $ly;
    my $lz; 
    my $xy;
    my $xz;
    my $yz;
    my $len;
    open my $data , "$Opt_data[$id]";
    my @data = <$data>;
    close $data;
    for(@data){

            if(m/(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\sxlo/s){
                $lx = $2-$1;
            }
            if(m/(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\sylo/s){
                $ly = $2-$1;
            }
            if(m/(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\szlo/s){
                $lz = $2-$1;
            }
            if(m/(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\s+xy\s+xz\s+yz/s){
                $xy = $1;
                $xz = $2;
                $yz = $3;
            }
        ###ATOMIC_POSITION###
            if(m/^\d+\s+(\d+)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s$/gm) #coord
            {
            my $x = $1-1;

            my $rand1 = $2 + (rand(2)-1)*$random; 
            my $rand2 = $3 + (rand(2)-1)*$random;
            my $rand3 = $4 + (rand(2)-1)*$random;
            `sed -i '/ATOMIC_POSITIONS {angstrom}/a $ele[$x] $rand1 $rand2 $rand3' $foldername/$changebox`; 

            } 

    }
################# positive ##################
    my $xy1 = $xy + $xy*$scale;
    my $xz1 = $xz + $xz*$scale;
    my $yz1 = $yz + $yz*$scale;
############  Change box +1 ################
    `cp $foldername/$changebox $foldername/Chg+1-$filename[$id].in`;
    $len = $lx;
    my $lx1 = $len + $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz1 $yz $lz ' $foldername/Chg+1-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy1 $ly 0 ' $foldername/Chg+1-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx1 0 0 ' $foldername/Chg+1-$filename[$id].in`;
###########  Change box +2 ################
    `cp $foldername/$changebox $foldername/Chg+2-$filename[$id].in`;
    $len = $ly;
    my $ly1 = $len + $len*$scale;


    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz1 $lz ' $foldername/Chg+2-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly1 0 ' $foldername/Chg+2-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg+2-$filename[$id].in`;
###########  Change box +3 ################
    `cp $foldername/$changebox $foldername/Chg+3-$filename[$id].in`;
    $len = $lz;
    my $lz1 = $len + $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz $lz1 ' $foldername/Chg+3-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0 ' $foldername/Chg+3-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg+3-$filename[$id].in`;
###########  Change box +4 ################
    `cp $foldername/$changebox $foldername/Chg+4-$filename[$id].in`;
    $len = $lz;
    $yz1 = $yz + $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz1 $lz ' $foldername/Chg+4-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0 ' $foldername/Chg+4-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg+4-$filename[$id].in`;
###########  Change box +5 ################
    `cp $foldername/$changebox $foldername/Chg+5-$filename[$id].in`;
    $len = $lz;
    $xz1 = $xz + $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz1 $yz $lz ' $foldername/Chg+5-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0 ' $foldername/Chg+5-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg+5-$filename[$id].in`;
###########  Change box +6 ################
    `cp $foldername/$changebox $foldername/Chg+6-$filename[$id].in`;  
    $len = $ly;
    $xy1 = $xy +$len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz $lz ' $foldername/Chg+6-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy1 $ly 0 ' $foldername/Chg+6-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg+6-$filename[$id].in`;

    for(1..6){
    `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --job-name=Chg+$_-$filename[$id]' $slurmbatch`;
	
	`sed -i '/#SBATCH.*--output/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --output=Chg+$_-$filename[$id].sout' $slurmbatch`;

	`sed -i '/mpiexec.*/d' $slurmbatch`;
	`sed -i '/#sed_anchor02/a mpiexec $QE_path -in Chg+$_-$filename[$id].in' $slurmbatch`;
    `cp $currentPath/QE_slurmEla.sh $foldername/Chg+$_-$filename[$id].sh`;

    if( exists $running{"Chg+$_-$filename[$id]"}){
      next;
    }
    if (-e "$foldername/Chg+$_-$filename[$id].sout" ){
      my $done =  `grep -o -a 'ATOMIC_POSITIONS (angstrom)' $foldername/Chg+$_-$filename[$id].sout | sed -n '\$p'`; 
      chomp $done;

      if( $done eq "ATOMIC_POSITIONS (angstrom)" ){
        next;
      }
    }
    # print qq($foldername\n);
    chdir("$foldername");
    system ("sbatch Chg+$_-$filename[$id].sh");
    chdir("$currentPath");
    print qq(sbatch $foldername/Chg+$_-$filename[$id].sh\n);



    }







##############  negative ##############
    my $xy2 = $xy - $xy*$scale;
    my $xz2 = $xz - $xz*$scale;
    my $yz2 = $yz - $yz*$scale;
###########  Change box -1 ################
    `cp $foldername/$changebox $foldername/Chg-1-$filename[$id].in`; 
    $len = $lx;
    my $lx2 = $len - $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz2 $yz $lz ' $foldername/Chg-1-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy2 $ly 0 ' $foldername/Chg-1-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx2 0 0 ' $foldername/Chg-1-$filename[$id].in`; 
###########  Change box -2 ################
    `cp $foldername/$changebox $foldername/Chg-2-$filename[$id].in`; 
    $len = $ly;
    my $ly2 = $len - $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz2 $lz ' $foldername/Chg-2-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly2 0 ' $foldername/Chg-2-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg-2-$filename[$id].in`;  
###########  Change box -3 ################
    `cp $foldername/$changebox $foldername/Chg-3-$filename[$id].in`;
    $len = $lz;
    my $lz2 = $len - $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz $lz2 ' $foldername/Chg-3-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0 ' $foldername/Chg-3-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg-3-$filename[$id].in`;
###########  Change box -4 ################
    `cp $foldername/$changebox $foldername/Chg-4-$filename[$id].in`;
    $len = $lz;
    $yz2 = $yz - $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz2 $lz ' $foldername/Chg-4-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0 ' $foldername/Chg-4-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg-4-$filename[$id].in`;
###########  Change box -5 ################
    `cp $foldername/$changebox $foldername/Chg-5-$filename[$id].in`;
    $len = $lz;
    $xz2 = $xz - $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz2 $yz $lz ' $foldername/Chg-5-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0 ' $foldername/Chg-5-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg-5-$filename[$id].in`;
###########  Change box -6 ################
    `cp $foldername/$changebox $foldername/Chg-6-$filename[$id].in`;       
    $len = $ly;
    $xy2 = $xy - $len*$scale;

    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz $lz ' $foldername/Chg-6-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy2 $ly 0 ' $foldername/Chg-6-$filename[$id].in`;
    `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0 ' $foldername/Chg-6-$filename[$id].in`;           

    for(1..6){
    `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --job-name=Chg-$_-$filename[$id]' $slurmbatch`;
	
	`sed -i '/#SBATCH.*--output/d' $slurmbatch`;
    `sed -i '/#sed_anchor01/a #SBATCH --output=Chg-$_-$filename[$id].sout' $slurmbatch`;
	
	`sed -i '/mpiexec.*/d' $slurmbatch`;
	`sed -i '/#sed_anchor02/a mpiexec $QE_path -in Chg-$_-$filename[$id].in' $slurmbatch`;
    `cp $currentPath/QE_slurmEla.sh $foldername/Chg-$_-$filename[$id].sh`;
    if( exists $running{"Chg-$_-$filename[$id]"}){
      next;
    }
    if (-e "$foldername/Chg-$_-$filename[$id].sout" ){
      my $done = `grep -o -a 'ATOMIC_POSITIONS (angstrom)' $foldername/Chg-$_-$filename[$id].sout | sed -n '\$p'`; 
      chomp $done;

      if( $done eq "ATOMIC_POSITIONS (angstrom)" ){
        next;
      }
    }

    # print qq($foldername\n);
    chdir("$foldername");
    system ("sbatch Chg-$_-$filename[$id].sh");
    chdir("$currentPath");
    print qq(sbatch $foldername/Chg-$_-$filename[$id].sh\n);


    }


    

}



