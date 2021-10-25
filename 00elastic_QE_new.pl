#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
####### Crontab Check #######

#########################################Set################################################
my $currentPath = getcwd();
my $user = "kevin";
my $slurmbatch = "QE_slurm.sh"; #slurm filename
my $QE_path = "/opt/QEGCC_MPICH3.4.2/bin/pw.x";
my $cleanall = "no";


my $changebox = "Changebox.in";
my @myelement = sort ("Co","Cr","Fe","Mn","Ni");
# "Hf","Nb",,"Ta","Ti","Zr"
my $myelement = join('',@myelement);


my $scale = 1.0e-3;
my $random = 1.0e-3;

my %HEA;
my %myelement;
for(0..$#myelement){
    $myelement{$_+1} = $myelement[$_];
}
for (@myelement){
    
    $HEA{"$_"}{magn} = 2.00000e-01;

}

my $opt_data = `find $currentPath/$myelement/Opt -maxdepth 2 -name "Opt-*-*.data"`;
my @opt_data = sort split("\n",$opt_data);
my @opt_name =  map (($_ =~ m/.*\/Opt-(.*).data$/gm),@opt_data);
my @opt_path =  map (($_ =~ m/(.*)\/.*.data$/gm),@opt_data);
my @element = map (($_ =~ m/-(.*)$/gm),@opt_name);


my $running = `/usr/local/bin/squeue -o \%j -u $user | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}


for my $id (0..$#opt_name){


  my $foldername = "$opt_path[$id]/Mix/elastic";
  my @ele = split("([A-Z][a-z])",$element[$id]);
  @ele = map (($_ =~ m/([A-Z][a-z])/gm),@ele);
  my $elelegth = @ele;
  my %magn;


    for(1..$elelegth){
        my $sed = "n;" x$_."p";
        my $magn = `cat $opt_path[$id]/Opt-$opt_name[$id].sout |sed -n '/atomic species   magnetization/{$sed}' | sed -n '\$p' |awk '{print \$2}'`;
        chomp $magn;
        $HEA{$myelement{$_}}{magn} = $magn ;
    }


if ($cleanall eq "no"){
    if (-e "$foldername/$changebox"){

        chdir("$foldername");
        ##############  pos  ##############
        for(1..6){
            my $pos = "Chg_$_-$opt_name[$id]";

            if( exists $running{"$pos"}){
                next;
            }
            if (-e "$foldername/$pos.sout" ){
                my $done =  `grep -o -a 'DONE' $foldername/$pos.sout | sed -n '\$p'`; 
                chomp $done;
                if( $done eq "DONE" ){
                    next;
                }
                my $atom_position =  `grep -o -a 'ATOMIC_POSITIONS (angstrom)' $foldername/$pos.sout | sed -n '\$p'`; 
                chomp $atom_position;
                if ($atom_position eq "ATOMIC_POSITIONS (angstrom)"){
                    open my $sout , "< $foldername/$pos.sout";
                    my @sout = <$sout>;
                    close($sout);
                    my @coord = grep {if(m/^(\w+)\s+([-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+)$/gm){
                    $_ = [$1,$2];}} @sout;
                    my $natom = `cat $foldername/$pos.sout |sed -n '/number of atoms\\/cell/p' | sed -n '\$p'| awk '{print \$5}'`;
                    `sed -i '/ATOMIC_POSITIONS.*/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $foldername/$pos.in`;
                    for(1..$natom){
                       `sed -i '/ATOMIC_POSITIONS.*/a $coord[-$_][0] $coord[-$_][1]' $foldername/$pos.in`;
                    }
                }
            }


    #         # `sed -i 's:ion_dynamics.*:ion_dynamics = "damp":'  $foldername/Chg+$_-$filename[$id].in`;
        print ("$pos\n");
           `/usr/local/bin/sbatch $foldername/$pos.sh`;
        }


        ###############  neg   ############### 
        for(1..6){
            my $neg = "Chg-$_-$opt_name[$id]";


            if( exists $running{"$neg"}){
                next;
            }
            if (-e "$foldername/$neg.sout" ){
                my $done =  `grep -o -a 'DONE' $foldername/$neg.sout | sed -n '\$p'`; 
                chomp $done;
                if( $done eq "DONE" ){
                    next;
                }
                my $atom_position =  `grep -o -a 'ATOMIC_POSITIONS (angstrom)' $foldername/$neg.sout | sed -n '\$p'`; 
                chomp $atom_position;
                if ($atom_position eq "ATOMIC_POSITIONS (angstrom)"){
                    open my $sout , "< $foldername/$neg.sout";
                    my @sout = <$sout>;
                    close($sout);
                    my @coord = grep {if(m/^(\w+)\s+([-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+)$/gm){
                    $_ = [$1,$2];}} @sout;
                    my $natom = `cat $foldername/$neg.sout |sed -n '/number of atoms\\/cell/p' | sed -n '\$p'| awk '{print \$5}'`;
                    `sed -i '/ATOMIC_POSITIONS.*/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $foldername/$neg.in`;
                    for(1..$natom){
                       `sed -i '/ATOMIC_POSITIONS.*/a $coord[-$_][0] $coord[-$_][1]' $foldername/$neg.in`;
                    }
                }

            }
    #         # `sed -i 's:ion_dynamics.*:ion_dynamics = "damp":'  $foldername/Chg-$_-$filename[$id].in` ;
        print ("$neg\n");
            `/usr/local/bin/sbatch $foldername/$neg.sh`;
        }
        chdir("$currentPath");
        next;    
    }
}

    `mkdir -p $foldername`;

    `cp $opt_path[$id]/Opt-$opt_name[$id].in $foldername/$changebox`;



    `sed -i 's:calculation.*:calculation = "relax":'  $foldername/$changebox` ;
    `sed -i '/!ionsend/,/!cellend/{/!ionsend/!{/!cellend/!d}}' $foldername/$changebox`;
    `sed -i '/ATOMIC_POSITIONS.*/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $foldername/$changebox`;
    `sed -i '/CELL_PARAMETERS.*/,/!End/{/CELL_PARAMETERS.*/!{/!End/!d}}' $foldername/$changebox`;
    for (1..$elelegth){
    `sed -i 's:starting_magnetization($_).*:starting_magnetization($_) = $HEA{$myelement{$_}}{magn}:' $foldername/$changebox`;
    } 


    my $lx;
    my $ly;
    my $lz; 
    my $xy;
    my $xz;
    my $yz;
    my $len;
    open my $data , "$opt_data[$id]";
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

            my $rand1 = $2 + (rand(2)-1)*$random; 
            my $rand2 = $3 + (rand(2)-1)*$random;
            my $rand3 = $4 + (rand(2)-1)*$random;
            `sed -i '/ATOMIC_POSITIONS.*/a $myelement{$1} $rand1 $rand2 $rand3' $foldername/$changebox`; 

            } 

    }
# ################# positive ##################
    my $xy1 = $xy + $xy*$scale;
    my $xz1 = $xz + $xz*$scale;
    my $yz1 = $yz + $yz*$scale;
############  Change box +1 ################
    `cp $foldername/$changebox $foldername/Chg_1-$opt_name[$id].in`;
    $len = $lx;
    my $lx1 = $len + $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz1 $yz $lz ' $foldername/Chg_1-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy1 $ly 0 ' $foldername/Chg_1-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx1 0 0 ' $foldername/Chg_1-$opt_name[$id].in`;
###########  Change box +2 ################
    `cp $foldername/$changebox $foldername/Chg_2-$opt_name[$id].in`;
    $len = $ly;
    my $ly1 = $len + $len*$scale;


    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz1 $lz ' $foldername/Chg_2-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly1 0 ' $foldername/Chg_2-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg_2-$opt_name[$id].in`;
###########  Change box +3 ################
    `cp $foldername/$changebox $foldername/Chg_3-$opt_name[$id].in`;
    $len = $lz;
    my $lz1 = $len + $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz $lz1 ' $foldername/Chg_3-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly 0 ' $foldername/Chg_3-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg_3-$opt_name[$id].in`;
###########  Change box +4 ################
    `cp $foldername/$changebox $foldername/Chg_4-$opt_name[$id].in`;
    $len = $lz;
    $yz1 = $yz + $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz1 $lz ' $foldername/Chg_4-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly 0 ' $foldername/Chg_4-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg_4-$opt_name[$id].in`;
###########  Change box +5 ################
    `cp $foldername/$changebox $foldername/Chg_5-$opt_name[$id].in`;
    $len = $lz;
    $xz1 = $xz + $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz1 $yz $lz ' $foldername/Chg_5-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly 0 ' $foldername/Chg_5-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg_5-$opt_name[$id].in`;
###########  Change box +6 ################
    `cp $foldername/$changebox $foldername/Chg_6-$opt_name[$id].in`;  
    $len = $ly;
    $xy1 = $xy +$len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz $lz ' $foldername/Chg_6-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy1 $ly 0 ' $foldername/Chg_6-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg_6-$opt_name[$id].in`;

    for(1..6){
        my $pos = "Chg_$_-$opt_name[$id]";

    `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --job-name=$pos' $slurmbatch`;
	
	`sed -i '/#SBATCH.*--output/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --output=$pos.sout' $slurmbatch`;

	`sed -i '/mpiexec.*/d' $slurmbatch`;
	`sed -i '/#sed_anchor02/a mpiexec $QE_path -in $foldername/$pos.in' $slurmbatch`;
    `cp $slurmbatch $foldername/$pos.sh`;


    chdir("$foldername");
    print ("$pos\n");
    `/usr/local/bin/sbatch $foldername/$pos.sh`;
    chdir("$currentPath");
    }





# ##############  negative ##############
    my $xy2 = $xy - $xy*$scale;
    my $xz2 = $xz - $xz*$scale;
    my $yz2 = $yz - $yz*$scale;
###########  Change box -1 ################
    `cp $foldername/$changebox $foldername/Chg-1-$opt_name[$id].in`; 
    $len = $lx;
    my $lx2 = $len - $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz2 $yz $lz ' $foldername/Chg-1-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy2 $ly 0 ' $foldername/Chg-1-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx2 0 0 ' $foldername/Chg-1-$opt_name[$id].in`; 
###########  Change box -2 ################
    `cp $foldername/$changebox $foldername/Chg-2-$opt_name[$id].in`; 
    $len = $ly;
    my $ly2 = $len - $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz2 $lz ' $foldername/Chg-2-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly2 0 ' $foldername/Chg-2-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg-2-$opt_name[$id].in`;  
###########  Change box -3 ################
    `cp $foldername/$changebox $foldername/Chg-3-$opt_name[$id].in`;
    $len = $lz;
    my $lz2 = $len - $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz $lz2 ' $foldername/Chg-3-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly 0 ' $foldername/Chg-3-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg-3-$opt_name[$id].in`;
###########  Change box -4 ################
    `cp $foldername/$changebox $foldername/Chg-4-$opt_name[$id].in`;
    $len = $lz;
    $yz2 = $yz - $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz2 $lz ' $foldername/Chg-4-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly 0 ' $foldername/Chg-4-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg-4-$opt_name[$id].in`;
###########  Change box -5 ################
    `cp $foldername/$changebox $foldername/Chg-5-$opt_name[$id].in`;
    $len = $lz;
    $xz2 = $xz - $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz2 $yz $lz ' $foldername/Chg-5-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy $ly 0 ' $foldername/Chg-5-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg-5-$opt_name[$id].in`;
###########  Change box -6 ################
    `cp $foldername/$changebox $foldername/Chg-6-$opt_name[$id].in`;       
    $len = $ly;
    $xy2 = $xy - $len*$scale;

    `sed -i '/CELL_PARAMETERS.*/a  $xz $yz $lz ' $foldername/Chg-6-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $xy2 $ly 0 ' $foldername/Chg-6-$opt_name[$id].in`;
    `sed -i '/CELL_PARAMETERS.*/a  $lx 0 0 ' $foldername/Chg-6-$opt_name[$id].in`;           

    for(1..6){
        my $neg = "Chg-$_-$opt_name[$id]";
    `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --job-name=$neg' $slurmbatch`;
	
	`sed -i '/#SBATCH.*--output/d' $slurmbatch`;
    `sed -i '/#sed_anchor01/a #SBATCH --output=$neg.sout' $slurmbatch`;
	
	`sed -i '/mpiexec.*/d' $slurmbatch`;
	`sed -i '/#sed_anchor02/a mpiexec $QE_path -in $foldername/$neg.in' $slurmbatch`;
    `cp $slurmbatch $foldername/$neg.sh`;

    chdir("$foldername");
    print ("$neg\n");
    `/usr/local/bin/sbatch $foldername/$neg.sh`;
    chdir("$currentPath");


    }


    

}



