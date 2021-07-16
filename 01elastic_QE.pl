use strict;
use warnings;
use Cwd;
#########################################Set################################################
my $currentPath = getcwd();
my $slurmbatch = "QE_slurmEla.sh"; #slurm filename
my $QE_path = "/opt/QEGCC_MPICH3.3.2/bin/pw.x";
my @myelement = sort ("Co","Cr","Fe","Hf","Mn","Nb","Ni","Ta","Ti","Zr");
my $myelement = join('',@myelement);


my $Opt_data = `find $currentPath/$myelement/Opt -maxdepth 2 -name "Opt-*-*.data"`;
my @Opt_data = split("\n",$Opt_data);
@Opt_data = sort @Opt_data;
my @opt_path =  map (($_ =~ m/(.*)\/.*.data$/gm),@Opt_data);
my @filename =  map (($_ =~ m/.*\/(.*).data$/gm),@Opt_data);

my $running = `squeue -o \%j | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}




for my $id (0..$#filename){
    my $foldername = "$opt_path[$id]/elastic";
    



    my $chg_in = `find $foldername -name "Chg*.in"`;
    my @chg_in = split("\n","$chg_in");
    @chg_in = sort @chg_in;
    my @chg_inname = map (($_ =~ m/.*\/(.*).in$/gm),@chg_in);
    for my $i (0..$#chg_in){

        if( exists $running{"Opt-$chg_inname[$i]"}){
        next;
        }
        if (-e "$foldername/Opt-$chg_inname[$i].sout" ){
        my $done = `grep -o -a 'DONE' $foldername/Opt-$chg_inname[$i].sout`; 
        chomp $done;

        if( $done eq "DONE" ){
            next;
        }
        }

        `cp $chg_in[$i] $foldername/Opt-$chg_inname[$i].in`;
        `sed -i 's:calculation.*:calculation = "vc-relax":'  $foldername/Opt-$chg_inname[$i].in` ;
        `sed -i 's:nstep.*:nstep = 1:' $foldername/Opt-$chg_inname[$i].in`;
        
        
        `sed -i '/!ionsend/a /' $foldername/Opt-$chg_inname[$i].in`;
        `sed -i '/!ionsend/a cell_dynamics = "bfgs"' $foldername/Opt-$chg_inname[$i].in`;
        `sed -i '/!ionsend/a press_conv_thr = 0' $foldername/Opt-$chg_inname[$i].in`;
        `sed -i '/!ionsend/a &CELL' $foldername/Opt-$chg_inname[$i].in`;


        if(-e "$foldername/$chg_inname[$i].sout"){
        open my $sout ,"< $foldername/$chg_inname[$i].sout";
        my @sout = <$sout>;
        close($sout);
        my $natom = `cat $foldername/$chg_inname[$i].sout|sed -n '/number of atoms\\/cell/p' | sed -n '\$p'| awk '{print \$5}'`;
        my @coord = grep {if(m/^(\w+)\s+([-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+)$/gm){
        $_ = [$1,$2];}} @sout;

        if(@coord){
            `sed -i '/ATOMIC_POSITIONS {angstrom/,/CELL_PARAMETERS {angstrom}/{/ATOMIC_POSITIONS {angstrom}/!{/CELL_PARAMETERS {angstrom}/!d}}' $foldername/Opt-$chg_inname[$i].in`;
            for(1..$natom){
                # print "$coord[-$_][0] $coord[-$_][1]\n";
                `sed -i '/ATOMIC_POSITIONS {angstrom}/a $coord[-$_][0] $coord[-$_][1]' $foldername/Opt-$chg_inname[$i].in`;
            }
        }
        # my $atom_positions =`tac $foldername/$chg_inname[$i].sout | sed -n '/End final coordinates/,/ATOMIC_POSITIONS (angstrom)/p' | tail -n +2 | head -n -1`;
        # my @atom_positions =split("\n",$atom_positions);
        # for(0..$#atom_positions){
        # `sed -i '/ATOMIC_POSITIONS {angstrom}/a $atom_positions[$_]' $foldername/Opt-$chg_inname[$i].in`;
        # }


        `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
        `sed -i '/#sed_anchor01/a #SBATCH --job-name=Opt-$chg_inname[$i]' $slurmbatch`;
        
        `sed -i '/#SBATCH.*--output/d' $slurmbatch`;
        `sed -i '/#sed_anchor01/a #SBATCH --output=Opt-$chg_inname[$i].sout' $slurmbatch`;
        
        `sed -i '/mpiexec.*/d' $slurmbatch`;
        `sed -i '/#sed_anchor02/a mpiexec $QE_path -in Opt-$chg_inname[$i].in' $slurmbatch`;
        `cp $currentPath/QE_slurmEla.sh $foldername/Opt-$chg_inname[$i].sh`;
        chdir("$foldername");
        system ("sbatch Opt-$chg_inname[$i].sh");
        print qq(sbatch Opt-$chg_inname[$i].sh\n);
        chdir("$currentPath");
        }

    }
}



