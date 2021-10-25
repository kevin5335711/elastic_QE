use strict;
use warnings;
use Cwd;
use Data::Dumper;
my $currentPath = getcwd();
my $user = "kevin";
my @myelement = sort ("Co","Cr","Fe","Mn","Ni");
# "Hf","Nb",,"Ta","Ti","Zr"
my $myelement = join ('',@myelement);


my $constant = 1.0e-3; #(delta/len0)=scale;


my $opt_file = `find $currentPath/$myelement/Opt -maxdepth 2 -name "Opt-*-*.sout"`;
my @opt_file = sort split("\n", $opt_file);
my @opt_path = map (($_ =~ m/(.*)\/.*.sout$/gm),@opt_file);
my @opt_name = map (($_ =~ m/.*\/(.*).sout$/gm),@opt_file);


my $running = `squeue -o \%j -u $user | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}


for my $id (0..$#opt_file){


    my $foldername = "$opt_path[$id]/Mix/elastic";
    if(-e $foldername){
    my @Call;
    my @px0;
    my @py0;
    my @pz0;

    
    my @pres0 = `cat $opt_file[$id] | sed -n '/total   stress/, +3 p' | awk '{print \$4,\$5,\$6}' | tail -n -3`;

    @px0 = split(" ",$pres0[0]);
    @py0 = split(" ",$pres0[1]);
    @pz0 = split(" ",$pres0[2]);

    my $chg_file = `find $foldername -name "Opt-*.sout"`;
    my @chg_file = sort split("\n", $chg_file);
    my @chg_name = map (($_ =~ m/-([0-9]-.*).sout$/gm),@chg_file);
    my @neg_filename = map (($_ =~ m/-(\w+).sout$/gm),@chg_file);



    open my $output ,">  $foldername/elastic_$opt_name[$id].dat";

    for my $id1 (0..$#chg_name){

        my $pos = "Opt-Chg_$chg_name[$id1]";
        my $neg = "Opt-Chg-$chg_name[$id1]";

        my $done1 = `grep -o -a 'DONE' $foldername/$pos.sout`; 
        chomp $done1;
        if($done1 ne "DONE" ||  exists $running{"$pos"}){
            print "$pos\n";
            last;
        }
        my $done2 = `grep -o -a 'DONE' $foldername/$neg.sout`; 
        chomp $done2;
        if($done2 ne "DONE" ||  exists $running{"$neg"}){
            print "$neg\n";
            last;
        }

        print "$chg_name[$id1]\n";

        my @px1;
        my @py1;
        my @pz1;
        my @Cneg;
        my @Cpos;
        my @C;
        my @pres1 = `cat $foldername/$neg.sout | sed -n '/total   stress/, +3 p' | awk '{print \$4,\$5,\$6}' | tail -n -3`;
        @px1 = split(" ",$pres1[0]);
        @py1 = split(" ",$pres1[1]);
        @pz1 = split(" ",$pres1[2]);

        # print Dumper @pres1;
        push (@Cneg, +($px1[0]-$px0[0])/$constant); #d1
        push (@Cneg, +($py1[1]-$py0[1])/$constant); #d2
        push (@Cneg, +($pz1[2]-$pz0[2])/$constant); #d3
        push (@Cneg, +($py1[2]-$py0[2])/$constant); #d4
        push (@Cneg, +($px1[2]-$px0[2])/$constant); #d5
        push (@Cneg, +($px1[1]-$px0[1])/$constant); #d6

        @pres1 = `cat $foldername/$pos.sout | sed -n '/total   stress/, +3 p' | awk '{print \$4,\$5,\$6}' | tail -n -3`;
        @px1 = split(" ",$pres1[0]);
        @py1 = split(" ",$pres1[1]);
        @pz1 = split(" ",$pres1[2]);

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
        my $C11cubic = ($Call[0][0]+$Call[1][1]+$Call[2][2])/30;
        my $C12cubic = ($Call[0][1]+$Call[0][2]+$Call[1][2])/30;
        my $C44cubic = ($Call[3][3]+$Call[4][4]+$Call[5][5])/30;
        my $bulk = ($C11cubic+2*$C12cubic)/3;

        print $output "C11  $C11cubic\n";
        print $output "C12  $C12cubic\n";
        print $output "C44  $C44cubic\n";
        print $output "bulk  $bulk\n";
        close $output;
    }
}


