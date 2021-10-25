use strict;
use warnings;
use Cwd;
#########################################Set################################################
my $currentPath = getcwd();
my $user = "kevin";
my $slurmbatch = "$currentPath/QE_slurm.sh"; #slurm filename
my $QE_path = "/opt/QEGCC_MPICH3.4.2/bin/pw.x";
my $changebox = "Changebox.in";
my @myelement = sort ("Co","Cr","Fe","Mn","Ni");
# "Hf","Nb",,"Ta","Ti","Zr"
my $myelement = join('',@myelement);

my $cleanall = "no";

my $nstep = 100;
my $scale = 0.01;
my $compress = 5;
my $tension = 5;

my %HEA;
my %myelement;
for(0..$#myelement){
    $myelement{$_+1} = $myelement[$_];
}
for (@myelement){
    
    $HEA{"$_"}{magn} = 2.00000e-01;

}


my $opt_data = `find $currentPath/$myelement/Opt -maxdepth 2 -name "Opt-*-[A-Z][a-z][A-Z][a-z].data"`;
my @opt_data = sort split("\n",$opt_data);
my @opt_name =  map (($_ =~ m/.*\/Opt-(.*).data$/gm),@opt_data);
my @opt_path =  map (($_ =~ m/(.*)\/.*.data$/gm),@opt_data);
my @element = map (($_ =~ m/-(.*)$/gm),@opt_name);


my $running = `squeue -o \%j -u $user | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}



for my $id (0..$#opt_name){


    my $foldername = "$opt_path[$id]/fittingTemplate";
    my @ele = split("([A-Z][a-z])",$element[$id]);
    @ele = map (($_ =~ m/([A-Z][a-z])/gm),@ele);
    my $elelegth = @ele;
   

    for(1..$elelegth){
        my $sed = "n;" x$_."p";
        my $magn = `cat $opt_path[$id]/Opt-$opt_name[$id].sout |sed -n '/atomic species   magnetization/{$sed}' | sed -n '\$p' |awk '{print \$2}'`;
        chomp $magn;
        $HEA{$myelement{$_}}{magn} = $magn ;
    }



if ($cleanall eq "no"){
    if (-e "$foldername/$changebox"){

        chdir("$foldername");

        #################   pos   ##############
        for(1..$tension){
            my $pos = "Ten-$_-$opt_name[$id]";
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
            print "$pos.sh\n";  
            system("sbatch $foldername/$pos.sh"); 
        }
}


        #################   neg   ##############
        for(1..$compress){

            my $neg = "Com-$_-$opt_name[$id]";
      
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
                    `sed -i '/ATOMIC_POSITIONS {angstrom/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $foldername/$neg.in`;
                    for(1..$natom){
                       `sed -i '/ATOMIC_POSITIONS.*/a $coord[-$_][0] $coord[-$_][1]' $foldername/$neg.in`;
                    }
                }
            }
            print "$neg.sh\n";  
            system("sbatch $foldername/$neg.sh");  
        }
        chdir("$currentPath");
        next;    
    }


    `mkdir -p $foldername`;
    `cp $opt_path[$id]/Opt-$opt_name[$id].in $foldername/$changebox`;

    `sed -i 's:^nstep.*:nstep = $nstep:' $foldername/$changebox`;
    `sed -i 's:calculation.*:calculation = "relax":'  $foldername/$changebox` ;
    `sed -i '/!ionsend/,/!cellend/{/!ionsend/!{/!cellend/!d}}' $foldername/$changebox`;
    `sed -i '/ATOMIC_POSITIONS.*/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $foldername/$changebox`;
    `sed -i '/CELL_PARAMETERS.*/,/!End/{/CELL_PARAMETERS.*/!{/!End/!d}}' $foldername/$changebox`;
    for (1..$elelegth){
    `sed -i 's:starting_magnetization($_).*:starting_magnetization($_) = $HEA{$myelement{$_}}{magn}:' $foldername/$changebox`;
    } 
    
    my $xhi;
    my $lx;
    my $yhi;
    my $ly;
    my $zhi;
    my $lz; 
    my $xy;
    my $xz;
    my $yz;
    open my $data , "$opt_data[$id]";
    my @data = <$data>;
    close $data;
    for(@data){

            if(m/(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\sxlo/s){
                $xhi = $2;
                $lx = $2-$1;
            }
            if(m/(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\sylo/s){
                $yhi = $2;
                $ly = $2-$1;
            }
            if(m/(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\szlo/s){
                $zhi = $2;
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


            `sed -i '/ATOMIC_POSITIONS.*/a  $myelement{$1} $2 $3 $4' $foldername/$changebox`; 

            } 

    }
        my $incrementx = $lx*$scale;
        my $incrementy = $ly*$scale;
        my $incrementz = $lz*$scale;


################# tension ##################
    for(1..$tension){
        my $xhi1 = $xhi + $_*$incrementx;
        my $yhi1 = $yhi + $_*$incrementy;
        my $zhi1 = $zhi + $_*$incrementz;

        my $pos = "Ten-$_-$opt_name[$id]";

        `cp $foldername/$changebox $foldername/$pos.in`;
        `sed -i '/CELL_PARAMETERS.*/a  $xz $yz $zhi1 ' $foldername/$pos.in`;
        `sed -i '/CELL_PARAMETERS.*/a  $xy $yhi1 0 ' $foldername/$pos.in`;
        `sed -i '/CELL_PARAMETERS.*/a  $xhi1 0 0 ' $foldername/$pos.in`; 

        `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
        `sed -i '/#sed_anchor01/a #SBATCH --job-name=$pos' $slurmbatch`;
        
        `sed -i '/#SBATCH.*--output/d' $slurmbatch`;
        `sed -i '/#sed_anchor01/a #SBATCH --output=$pos.sout' $slurmbatch`;
        
        `sed -i '/mpiexec.*/d' $slurmbatch`;
        `sed -i '/#sed_anchor02/a mpiexec $QE_path -in $foldername/$pos.in' $slurmbatch`;
        `cp $slurmbatch $foldername/$pos.sh`;


        chdir("$foldername");
        print "$pos.sh\n";  
        system("sbatch $foldername/$pos.sh");
        chdir("$currentPath");
        }

################# compress ##################

    for(1..$compress){
        my $xhi1 = $xhi - $_*$incrementx;
        my $yhi1 = $yhi - $_*$incrementy;
        my $zhi1 = $zhi - $_*$incrementz;

        my $neg = "Com-$_-$opt_name[$id]";

        `cp $foldername/$changebox $foldername/$neg.in`;
        `sed -i '/CELL_PARAMETERS.*/a  $xz $yz $zhi1 ' $foldername/$neg.in`;
        `sed -i '/CELL_PARAMETERS.*/a  $xy $yhi1 0 ' $foldername/$neg.in`;
        `sed -i '/CELL_PARAMETERS.*/a  $xhi1 0 0 ' $foldername/$neg.in`; 

        `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
        `sed -i '/#sed_anchor01/a #SBATCH --job-name=$neg' $slurmbatch`;
        
        `sed -i '/#SBATCH.*--output/d' $slurmbatch`;
        `sed -i '/#sed_anchor01/a #SBATCH --output=$neg.sout' $slurmbatch`;
        
        `sed -i '/mpiexec.*/d' $slurmbatch`;
        `sed -i '/#sed_anchor02/a mpiexec $QE_path -in $foldername/$neg.in' $slurmbatch`;
        `cp $slurmbatch $foldername/$neg.sh`;

        chdir("$foldername");
        print "$neg.sh\n";  
        system("sbatch $foldername/$neg.sh");
        chdir("$currentPath");
        }    

    

}



