use strict;
use warnings;
use Cwd;
my $currentPath = getcwd();
my @myelement = sort ("Co","Cr","Fe","Hf","Mn","Nb","Ni","Ta","Ti","Zr");
my $myelement = join ('',@myelement);

my $opt_file = `find $currentPath/$myelement/Opt -maxdepth 2 -name "Opt-*-*.sout"`;
my @opt_file = split("\n", $opt_file);
@opt_file = sort @opt_file;
my @opt_filepath = map (($_ =~ m/(.*)\/.*.sout$/gm),@opt_file);
my @opt_filename = map (($_ =~ m/.*\/(.*).sout$/gm),@opt_file);


my $running = `squeue -o \%j | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}

my $constant = 1.0e-3; #(delta/len0)=scale;


for my $id (0..$#opt_file){

    my @Call;
    my @px0;
    my @py0;
    my @pz0;

    my @pres0 = `cat $opt_file[$id] | sed -n '/Computing stress/, +5 p' | awk '{print \$4,\$5,\$6}' | tail -n -3`;
    @px0 = split(" ",$pres0[0]);
    @py0 = split(" ",$pres0[1]);
    @pz0 = split(" ",$pres0[2]);
    

    my $chg_file = `find $opt_filepath[$id]/elastic -name "Opt-*.sout"`;
    my @chg_file = split("\n", $chg_file);
    @chg_file = sort @chg_file;
    my @chg_filename = map (($_ =~ m/-([0-9]-\w+.\w+).sout$/gm),@chg_file);
    # my @neg_filename = map (($_ =~ m/-(\w+).sout$/gm),@chg_file);



    open my $output ,">  $opt_filepath[$id]/elastic/elastic_$opt_filename[$id].dat";

    for my $id1 (0..$#chg_filename){

        my $done1 = `grep -o -a 'DONE' $opt_filepath[$id]/elastic/Opt-Chg-$chg_filename[$id1].sout`; 
        chomp $done1;
        if($done1 ne "DONE" ||  exists $running{"Opt-Chg-$chg_filename[$id1]"}){
            print "Opt-Chg-$chg_filename[$id1]\n";
            last;
        }
        my $done2 = `grep -o -a 'DONE' $opt_filepath[$id]/elastic/Opt-Chg+$chg_filename[$id1].sout`; 
        chomp $done2;
        if($done2 ne "DONE" ||  exists $running{"Opt-Chg+$chg_filename[$id1]"}){
            print "Opt-Chg+$chg_filename[$id1]\n";
            last;
        }

        my @px1;
        my @py1;
        my @pz1;
        my @Cneg;
        my @Cpos;
        my @C;
        my @pres1 = `cat $opt_filepath[$id]/elastic/Opt-Chg-$chg_filename[$id1].sout | sed -n '/Computing stress/, +5 p' | awk '{print \$4,\$5,\$6}' | tail -n -3`;
        @px1 = split(" ",$pres1[0]);
        @py1 = split(" ",$pres1[1]);
        @pz1 = split(" ",$pres1[2]);

        push (@Cneg, +($px1[0]-$px0[0])/$constant); #d1
        push (@Cneg, +($py1[1]-$py0[1])/$constant); #d2
        push (@Cneg, +($pz1[2]-$pz0[2])/$constant); #d3
        push (@Cneg, +($py1[2]-$py0[2])/$constant); #d4
        push (@Cneg, +($px1[2]-$px0[2])/$constant); #d5
        push (@Cneg, +($px1[1]-$px0[1])/$constant); #d6

        @pres1 = `cat $opt_filepath[$id]/elastic/Opt-Chg+$chg_filename[$id1].sout | sed -n '/Computing stress/, +5 p' | awk '{print \$4,\$5,\$6}' | tail -n -3`;
        @px1 = split(" ",$pres1[0]);
        @py1 = split(" ",$pres1[1]);
        @pz1 = split(" ",$pres1[2]);

# + 07/06
        push (@Cpos, -($px1[0]-$px0[0])/$constant); #d1
        push (@Cpos, -($py1[1]-$py0[1])/$constant); #d2
        push (@Cpos, -($pz1[2]-$pz0[2])/$constant); #d3
        push (@Cpos, -($py1[2]-$py0[2])/$constant); #d4
        push (@Cpos, -($px1[2]-$px0[2])/$constant); #d5
        push (@Cpos, -($px1[1]-$px0[1])/$constant); #d6


        for(0..5){
        push (@C, 0.5*($Cpos[$_]+$Cneg[$_]));
        }
        push (@Call, \@C);

         for(0..5){
             print $output "$_  $Cneg[$_] + $Cpos[$_] = 2 $C[$_]  \n";
         }
         print $output "\n";
    }

        for my $x (0..5){
            for my $y (0..5){

                $Call[$x][$y] = 0.5*($Call[$x][$y]+$Call[$y][$x]);
                $Call[$y][$x] = $Call[$x][$y];
                print $output "$Call[$x][$y]\t\t";
            } 
            print $output "\n";
        }
        my $C11cubic = ($Call[0][0]+$Call[1][1]+$Call[2][2])/3;
        my $C12cubic = ($Call[0][1]+$Call[0][2]+$Call[1][2])/3;
        my $C44cubic = ($Call[3][3]+$Call[4][4]+$Call[5][5])/3;
        my $bulk = ($C11cubic+2*$C12cubic)/3;

        print $output "C11  $C11cubic\n";
        print $output "C12  $C12cubic\n";
        print $output "C44  $C44cubic\n";
        print $output "bulk  $bulk\n";
        close $output;

}


