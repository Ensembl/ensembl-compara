#!/usr/local/ensembl/bin/perl -w

my $description = q{
###########################################################################
##
## PROGRAM create_mlss_table.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This modules is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script creates an HTML table from the information in the
##    method_link_species_set and method_link tables. The HTML table
##    is intended for the web help pages.
##
###########################################################################

};

=head1 NAME

create_mlss_table.pl

=head1 AUTHORS

 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script creates an HTML table from the information in the
method_link_species_set and method_link tables. The HTML table
is intended for the web help pages.

=head1 SYNOPSIS

perl create_mlss_table.pl
    [--reg_conf registry_configuration_file]
    [--dbname compara_db_name]
    [--output_file filename]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

the Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<[--dbname compara_db_name]>
  
the name of compara DB in the registry_configuration_file or any
of its aliases. Uses "compara" by default.

=back

=head2 OUTPUT

=over

=item B<[--output_file filename]>
  
The name of the output file. By default the output is the
standard output

=back

=cut

our $species;
our $high_cons_methods;
our $self_methods;
our $cons_methods;
our $ignored_methods;

my $conf_file_name = $0;
$conf_file_name =~ s/(\.pl)?$/\.conf/;
do "$conf_file_name";


my $usage = qq{
perl create_mlss_table.pl
  Getting help:
    [--help]
  
  General Configuration
    [--reg_conf registry_configuration_file]
        the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if
        defined, if not ~/.ensembl_init will be used.
    [--dbname compara_db_name]
        the name of compara DB in the registry_configuration_file or
        any of its aliases. Uses "compara" by default.

  Ouput:
    [--output_file filename]
        The name of the output file. By default the output is the
        standard output
};

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;

my $reg_conf;
my $dbname = "compara";
my $output_file = undef;
my $help;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "dbname=s" => \$dbname,
    "output_file=s" => \$output_file,
  );

# Print Help and exit
if ($help) {
  print $description, $usage;
  exit(0);
}

if ($output_file) {
  open(STDOUT, ">$output_file") or die("Cannot open $output_file");
}

# Configure the Bio::EnsEMBL::Registry
# Uses $reg_conf if supllied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses ~/.ensembl_init
# if all the previous fail.
Bio::EnsEMBL::Registry->load_all($reg_conf);


## Get the adaptor from the Registry
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');

## fetch all the method_link_species_sets
my $all_method_link_species_sets = $method_link_species_set_adaptor->fetch_all();

my $table;
foreach my $this_method_link_species_set (@{$all_method_link_species_sets}) {
  my $this_method_link_type = $this_method_link_species_set->method_link_type();
  my $genome_db_names;
  foreach my $genome_db (@{$this_method_link_species_set->species_set}) {
    my $genome_db_name = $genome_db->name;
    push (@$genome_db_names, $genome_db_name);
  }
  foreach my $genome_db_name_1 (@$genome_db_names) {
    foreach my $genome_db_name_2 (@$genome_db_names) {
      next if ($genome_db_name_1 eq $genome_db_name_2);
      if (!defined($high_cons_methods->{$this_method_link_type}) and
          !defined($self_methods->{$this_method_link_type}) and
          !defined($cons_methods->{$this_method_link_type}) and
          !defined($ignored_methods->{$this_method_link_type})) {
        throw("METHOD_LINK: $this_method_link_type ($genome_db_name_1 - $genome_db_name_2) has not been configured");
      }
      push(@{$table->{$genome_db_name_1}->{$genome_db_name_2}}, $this_method_link_type);
    }
  }
}

## Will have to sort in a better way...
my @all_genome_db_names = sort {$a cmp $b} keys %{$table};

print qq{<table bgcolor="#FFFFCC" border="0">\r\n\r\n};

print "<tr>\r\n<th></th>\r\n";
for (my $i=0; $i<@$species; $i++) {
  my $formatted_name = $species->[$i]->{long_name};
  $formatted_name =~ s/ /<br>/g;
  print "<th><i>$formatted_name</i></th>\r\n";
}
print "<th></th>\r\n</tr>\r\n\r\n";

for (my $i=0; $i<@$species; $i++) {
  print qq{<tr>\r\n<td align="left"><b><i>}, $species->[$i]->{short_name}, qq{</i></b></td>\r\n};
  for (my $j=0; $j<@$species; $j++) {
    my $all_method_links = $table->{$species->[$i]->{long_name}}->{$species->[$j]->{long_name}};
    my $these_method_links = [];
    if ($i > $j) {
      print qq{<td align="center" bgcolor="#FFFF99">};
      foreach my $this_method_link (@$all_method_links) {
        if (defined($cons_methods->{$this_method_link})) {
          push(@$these_method_links, $this_method_link);
        }
      }
      @$these_method_links = sort {$cons_methods->{$a}->{order} <=> $cons_methods->{$b}->{order}}
          @$these_method_links;
      @$these_method_links = map {$cons_methods->{$_}->{string}} @$these_method_links;
    } elsif ($i == $j) {
      print qq{<td align="center" bgcolor="#FFFFCC">};
      foreach my $this_method_link (@$all_method_links) {
        if (defined($self_methods->{$this_method_link})) {
          push(@$these_method_links, $this_method_link);
        }
      }
      @$these_method_links = sort {$self_methods->{$a}->{order} <=> $self_methods->{$b}->{order}}
          @$these_method_links;
      @$these_method_links = map {$self_methods->{$_}->{string}} @$these_method_links;
    } else {
      print qq{<td align="center" bgcolor="#FFCC33">};
      foreach my $this_method_link (@$all_method_links) {
        if (defined($high_cons_methods->{$this_method_link})) {
          push(@$these_method_links, $this_method_link);
        }
      }
      @$these_method_links = sort {$high_cons_methods->{$a}->{order} <=> $high_cons_methods->{$b}->{order}}
          @$these_method_links;
      @$these_method_links = map {$high_cons_methods->{$_}->{string}} @$these_method_links;
    }
    
    if ($these_method_links and @$these_method_links) {
      print join("\r\n", @$these_method_links);
    } else {
      print "-";
    }
    print qq{</td><!-- }, $species->[$j]->{short_name}, qq{ -->\r\n};
  }
  print qq{<td align="left"><b><i>}, $species->[$i]->{short_name}, qq{</i></b></td>\r\n};
  print "</tr>\r\n\r\n";
}

print "<tr>\r\n\r\n<td> <br> <br> </td>\r\n\r\n";
for (my $i=0; $i<@$species; $i++) {
  my $formatted_name = $species->[$i]->{long_name};
  my $img_name = $species->[$i]->{img_name};
  my $img_url = $species->[$i]->{img_url};
  my $link_url = $formatted_name;
  $link_url =~ s/ /_/g;
  print qq!<td align="center" bgcolor="#FFFFCC"><a href="/$link_url/" onmouseout="MM_swapImgRestore()" onmouseover="MM_swapImage('$img_name','','/gfx/rollovers/${img_name}1_do.gif',1)" target="external"><img id="$img_name" border="0" width="90" height="20" src="/gfx/rollovers/${img_name}1_up.gif" alt="Ensembl - $formatted_name" title="Ensembl - $formatted_name"></a></td>\r\n\r\n!;
}
print qq{<td></td>\r\n\r\n</tr>\r\n\r\n};


print "</table>\r\n";

