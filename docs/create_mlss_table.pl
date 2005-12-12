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
our $top_methods;
our $diagonal_methods;
our $bottom_methods;
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
    [--method_link method_link_type]
        restrict the output to this method_link_type. This can be
        used several times to add more method_link_types.

  Ouput:
    [--list]
        Print a list-like table instead of the full table
    [--trim]
        Trim the species not used when printing the table
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
my $method_link_type = undef;
my $list = undef;
my $trim = undef;
my $output_file = undef;
my $help;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "dbname=s" => \$dbname,
    "method_link_type=s@" => \$method_link_type,
    "list" => \$list,
    "trim" => \$trim,
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
my $all_method_link_species_sets = [];
if ($method_link_type) {
  foreach my $this_method_link_type (@$method_link_type) {
    push(@$all_method_link_species_sets,
        @{$method_link_species_set_adaptor->fetch_all_by_method_link_type($this_method_link_type)});
  }
} else {
  $all_method_link_species_sets = $method_link_species_set_adaptor->fetch_all();
}


if ($list) {
  print_html_list($all_method_link_species_sets);
} elsif ($method_link_type) {
  print_half_html_table($all_method_link_species_sets);
} else {
  print_full_html_table($all_method_link_species_sets);
}

exit(0);


sub print_html_list {
  my ($all_method_link_species_sets) = @_;

  print qq{<table bgcolor="#FFFFCC" border="0">\r\n\r\n};
  
  print "<tr>\r\n<th>Analysis</th>\r\n<th>Specie(s)</th>\r\n";
  print "</tr>\r\n\r\n";
  @$all_method_link_species_sets = sort {
          ($a->method_link_id <=> $b->method_link_id) or ($a->dbID <=> $b->dbID)
      } @$all_method_link_species_sets;
      
  my $these_method_link_species_sets = [];
  foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
    if (defined($bottom_methods->{$this_method_link_species_set->method_link_type})) {
      push(@$these_method_link_species_sets, $this_method_link_species_set);
    } elsif (defined($diagonal_methods->{$this_method_link_species_set->method_link_type})) {
      push(@$these_method_link_species_sets, $this_method_link_species_set);
      $bottom_methods->{$this_method_link_species_set->method_link_type} =
          $diagonal_methods->{$this_method_link_species_set->method_link_type};
    } elsif (defined($top_methods->{$this_method_link_species_set->method_link_type})) {
      push(@$these_method_link_species_sets, $this_method_link_species_set);
      $bottom_methods->{$this_method_link_species_set->method_link_type} =
          $top_methods->{$this_method_link_species_set->method_link_type};
    } elsif (defined($ignored_methods->{$this_method_link_species_set->method_link_type})) {
      push(@$these_method_link_species_sets, $this_method_link_species_set);
      $bottom_methods->{$this_method_link_species_set->method_link_type} =
          $ignored_methods->{$this_method_link_species_set->method_link_type};
    }
  }
  foreach my $this_method_link_species_set (@$these_method_link_species_sets) {
    print "<tr><th>",
        sprintf($bottom_methods->{$this_method_link_species_set->method_link_type}->{string},
            scalar(@{$this_method_link_species_set->species_set()})),
        "</th><td bgcolor=\"#FFCC33\">",
        join(", ", map {$_->{name}} @{$this_method_link_species_set->species_set()}),
        "</td></tr>\r\n";
  }
  print "</table>\r\n";

}


sub print_full_html_table {
  my ($all_method_link_species_sets) = @_;

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
  #       next if ($genome_db_name_1 eq $genome_db_name_2);
        if (!defined($top_methods->{$this_method_link_type}) and
            !defined($diagonal_methods->{$this_method_link_type}) and
            !defined($bottom_methods->{$this_method_link_type}) and
            !defined($ignored_methods->{$this_method_link_type})) {
          throw("METHOD_LINK: $this_method_link_type ($genome_db_name_1 - $genome_db_name_2) has not been configured");
        }
        push(@{$table->{$genome_db_name_1}->{$genome_db_name_2}}, $this_method_link_species_set);
      }
    }
  }

  if ($trim) {
    ## Trim the set of species
    for (my $i = @$species - 1; $i >= 0; $i--) {
      splice(@$species, $i, 1) if (!defined($table->{$species->[$i]->{long_name}}));
    }
  }

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
      my $all_method_link_species_sets = $table->{$species->[$i]->{long_name}}->{$species->[$j]->{long_name}};
      my $these_method_link_species_sets = [];
      if ($i > $j) {
        print qq{<td align="center" bgcolor="#FFFF99">};
        foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
          if (defined($bottom_methods->{$this_method_link_species_set->method_link_type})) {
            push(@$these_method_link_species_sets, $this_method_link_species_set);
          }
        }
        @$these_method_link_species_sets = sort {$bottom_methods->{$a->method_link_type}->{order}
            <=> $bottom_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {sprintf($bottom_methods->{$_->method_link_type}->{string},
            scalar(@{$_->species_set()}))} @$these_method_link_species_sets;
      } elsif ($i == $j) {
        print qq{<td align="center" bgcolor="#FFFFCC">};
        foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
          if (defined($diagonal_methods->{$this_method_link_species_set->method_link_type})) {
            push(@$these_method_link_species_sets, $this_method_link_species_set);
          }
        }
        @$these_method_link_species_sets = sort {$diagonal_methods->{$a->method_link_type}->{order}
            <=> $diagonal_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {sprintf($diagonal_methods->{$_->method_link_type}->{string},
            scalar(@{$_->species_set()}))} @$these_method_link_species_sets;
  #       foreach my $this_method_link (map {$_->method_link_type} @$all_method_link_species_sets) {
  #         if (defined($diagonal_methods->{$this_method_link})) {
  #           push(@$these_method_links, $this_method_link);
  #         }
  #       }
  #       @$these_method_links = sort {$diagonal_methods->{$a}->{order} <=> $diagonal_methods->{$b}->{order}}
  #           @$these_method_links;
  #       @$these_method_links = map {$diagonal_methods->{$_}->{string}} @$these_method_links;
      } else {
        print qq{<td align="center" bgcolor="#FFCC33">};
        foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
          if (defined($top_methods->{$this_method_link_species_set->method_link_type})) {
            push(@$these_method_link_species_sets, $this_method_link_species_set);
          }
        }
        @$these_method_link_species_sets = sort {$top_methods->{$a->method_link_type}->{order}
            <=> $top_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {sprintf($top_methods->{$_->method_link_type}->{string},
            scalar(@{$_->species_set}))} @$these_method_link_species_sets;
      }
      
      if (@$these_method_link_species_sets) {
        print join("<BR>\r\n", @$these_method_link_species_sets);
      } else {
        print "-";
      }
      print qq{</td><!-- }, $species->[$j]->{short_name}, qq{ -->\r\n};
    }
    print qq{<td align="left"><b><i>}, $species->[$i]->{short_name}, qq{</i></b></td>\r\n};
    print "</tr>\r\n\r\n";
  }
  
  # print "<tr>\r\n\r\n<td> <br> <br> </td>\r\n\r\n";
  # for (my $i=0; $i<@$species; $i++) {
  #   my $formatted_name = $species->[$i]->{long_name};
  #   my $img_name = $species->[$i]->{img_name};
  #   my $img_url = $species->[$i]->{img_url};
  #   my $link_url = $formatted_name;
  #   $link_url =~ s/ /_/g;
  #   print qq!<td align="center" bgcolor="#FFFFCC"><a href="/$link_url/" onmouseout="MM_swapImgRestore()" onmouseover="MM_swapImage('$img_name','','/gfx/rollovers/${img_name}1_do.gif',1)" target="external"><img id="$img_name" border="0" width="90" height="20" src="/gfx/rollovers/${img_name}1_up.gif" alt="Ensembl - $formatted_name" title="Ensembl - $formatted_name"></a></td>\r\n\r\n!;
  # }
  # print qq{<td></td>\r\n\r\n</tr>\r\n\r\n};
  
  
  print "</table>\r\n";

}


sub print_half_html_table {
  my ($all_method_link_species_sets) = @_;

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
  #       next if ($genome_db_name_1 eq $genome_db_name_2);
        if (!defined($top_methods->{$this_method_link_type}) and
            !defined($diagonal_methods->{$this_method_link_type}) and
            !defined($bottom_methods->{$this_method_link_type}) and
            !defined($ignored_methods->{$this_method_link_type})) {
          throw("METHOD_LINK: $this_method_link_type ($genome_db_name_1 - $genome_db_name_2) has not been configured");
        }
        push(@{$table->{$genome_db_name_1}->{$genome_db_name_2}}, $this_method_link_species_set);
      }
    }
  }

  if ($trim) {
    ## Trim the set of species
    for (my $i = @$species - 1; $i >= 0; $i--) {
      splice(@$species, $i, 1) if (!defined($table->{$species->[$i]->{long_name}}));
    }
  }

  print qq{<table bgcolor="#FFFFCC" border="0">\r\n\r\n};
  
  for (my $i=0; $i<@$species; $i++) {
    if ($i % 2) {
      print qq{<tr>\r\n<td bgcolor="#FFFFDD" align="left"><b><i>}, $species->[$i]->{long_name}, qq{</i></b></td>\r\n};
    } else {
      print qq{<tr>\r\n<td bgcolor="#FFFF99" align="left"><b><i>}, $species->[$i]->{long_name}, qq{</i></b></td>\r\n};
    }
    for (my $j=0; $j<$i; $j++) {
      my $all_method_link_species_sets = $table->{$species->[$i]->{long_name}}->{$species->[$j]->{long_name}};
      my $these_method_link_species_sets = [];
      if ($i % 2) {
        if ($j % 2) {
          print qq{<td align="center" bgcolor="#FFFFDD">};
        } else {
          print qq{<td align="center" bgcolor="#FFFF99">};
        }
      } else {
        if ($j % 2) {
          print qq{<td align="center" bgcolor="#FFFF99">};
        } else {
          print qq{<td align="center" bgcolor="#FFFF00">};
        }
      }
      foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
        if (defined($bottom_methods->{$this_method_link_species_set->method_link_type})) {
          push(@$these_method_link_species_sets, $this_method_link_species_set);
        } elsif ($method_link_type and defined($top_methods->{$this_method_link_species_set->method_link_type})) {
          push(@$these_method_link_species_sets, $this_method_link_species_set);
          $bottom_methods->{$this_method_link_species_set->method_link_type} =
              $top_methods->{$this_method_link_species_set->method_link_type};
        }
      }
      if (@$method_link_type == 1) {
        @$these_method_link_species_sets = map {"<font color=\"blue\">YES</font>"} @$these_method_link_species_sets;
      } else {
        @$these_method_link_species_sets = sort {$bottom_methods->{$a->method_link_type}->{order}
            <=> $bottom_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {sprintf($bottom_methods->{$_->method_link_type}->{string},
            scalar(@{$_->species_set()}))} @$these_method_link_species_sets;
      }
      
      if (@$these_method_link_species_sets) {
        print join("<BR>\r\n", @$these_method_link_species_sets);
      } else {
        print "-";
      }
      print qq{</td><!-- }, $species->[$j]->{short_name}, qq{ -->\r\n};
    }
    if ($i % 2) {
      print qq{<th align=center bgcolor="#FFFFDD" width=40><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    } else {
      print qq{<th align=center bgcolor="#FFFF00" width=40><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    }
    print "</tr>\r\n\r\n";
  }
  
  print "<tr>\r\n<th></th>\r\n";
  for (my $i=0; $i<@$species; $i++) {
    if ($i % 2) {
      print qq{<th align=center bgcolor="#FFFFDD" width=40><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    } else {
      print qq{<th align=center bgcolor="#FFFF99" width=40><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    }
  }
  print "<th></th>\r\n</tr>\r\n\r\n";
  
  print "</table>\r\n";

}
