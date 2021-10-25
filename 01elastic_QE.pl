use strict;
use warnings;
use Cwd;
#########################################Set################################################
my $currentPath = getcwd();
my $user = "kevin";
my $slurmbatch = "QE_slurm.sh"; #slurm filename
my $QE_path = "/opt/QEGCC_MPICH3.4.2/bin/pw.x";
my @myelement = sort ("Co","Cr","Fe","Mn","Ni");
# "Hf","Nb",,"Ta","Ti","Zr"
my $myelement = join('',@myelement);

my $cleanall = "no";


my $opt_data = `find $currentPath/$myelement/Opt -maxdepth 2 -name "Opt-*-*.data"`;
my @opt_data =sort split("\n",$opt_data);
my @opt_path =  map (($_ =~ m/(.*)\/.*.data$/gm),@opt_data);
my @opt_name =  map (($_ =~ m/.*\/(.*).data$/gm),@opt_data);

my $running = `/usr/local/bin/squeue -o \%j -u $user | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}




for my $id (0..$#opt_name){

    
    my $foldername = "$opt_path[$id]/Mix/elastic";


    my $chg_in = `find $foldername -name "Chg*.in"`;
    my @chg_in = sort split("\n","$chg_in");
    my @chg_inname = map (($_ =~ m/.*\/(.*).in$/gm),@chg_in);
    for my $i (0..$#chg_in){

            my $opt = "Opt-$chg_inname[$i]";

        if ( $cleanall eq "no" ){
            if( exists $running{"$opt"}){
                next;
            }
            if (-e "$foldername/$opt.sout"){
                my $done = `grep -o -a 'DONE' $foldername/$opt.sout`; 
                chomp $done;
                if( $done eq "DONE" ){
                    next;
                }
            }
        }
        
        if (-e "$foldername/$chg_inname[$i].sout"){
            if( exists $running{"$chg_inname[$i]"}){
                next;
            }
            my $done = `grep -o -a 'DONE' $foldername/$chg_inname[$i].sout`;
            chomp $done;
            if ($done eq "DONE"){
                `cp $chg_in[$i] $foldername/$opt.in`;
                `sed -i 's:calculation.*:calculation = "scf":'  $foldername/$opt.in` ;
                `sed -i '/nstep.*/d ' $foldername/$opt.in`;
                `sed -i '/calculation.*/a tstress=.TRUE.' $foldername/$opt.in`;
                `sed -i '/calculation.*/a tprnfor=.TRUE.' $foldername/$opt.in`;

                `sed -i '/ATOMIC_POSITIONS.*/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $foldername/$opt.in`;
                `sed -i '/!electronsend/,/!cellend/{/!electronsend/!{/!cellend/!d}}' $foldername/$opt.in`;

                open my $sout ,"< $foldername/$chg_inname[$i].sout";
                my @sout = <$sout>;
                close($sout);
                my $natom = `cat $foldername/$chg_inname[$i].sout|sed -n '/number of atoms\\/cell/p' | sed -n '\$p'| awk '{print \$5}'`;
                my @coord = grep {if(m/^(\w+)\s+([-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+)$/gm){
                $_ = [$1,$2];}} @sout;

                if(@coord){
                    `sed -i '/ATOMIC_POSITIONS.*/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $foldername/$opt.in`;
                    for(1..$natom){
                        # print "$coord[-$_][0] $coord[-$_][1]\n";
                        `sed -i '/ATOMIC_POSITIONS.*/a $coord[-$_][0] $coord[-$_][1]' $foldername/$opt.in`;
                    }
                }
                # my $atom_positions =`tac $foldername/$chg_inname[$i].sout | sed -n '/End final coordinates/,/ATOMIC_POSITIONS (angstrom)/p' | tail -n +2 | head -n -1`;
                # my @atom_positions =split("\n",$atom_positions);
                # for(0..$#atom_positions){
                # `sed -i '/ATOMIC_POSITIONS.*/a $atom_positions[$_]' $foldername/Opt-$chg_inname[$i].in`;
                # }


                `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
                `sed -i '/#sed_anchor01/a #SBATCH --job-name=$opt' $slurmbatch`;
                
                `sed -i '/#SBATCH.*--output/d' $slurmbatch`;
                `sed -i '/#sed_anchor01/a #SBATCH --output=$opt.sout' $slurmbatch`;
                
                `sed -i '/mpiexec.*/d' $slurmbatch`;
                `sed -i '/#sed_anchor02/a mpiexec $QE_path -in $opt.in' $slurmbatch`;
                `cp $currentPath/$slurmbatch $foldername/$opt.sh`;
                chdir("$foldername");
                `/usr/local/bin/sbatch $foldername/$opt.sh`;
                print qq(sbatch $foldername/$opt.sh\n);
                chdir("$currentPath");
            }

        }

    }
}



