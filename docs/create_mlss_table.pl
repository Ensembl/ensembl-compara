#!/usr/local/ensembl/bin/perl

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

use Bio::EnsEMBL::Compara::Graph::NewickParser;

our $species;
our $top_methods;
our $diagonal_methods;
our $bottom_methods;
our $ignored_methods;

my $conf_file_name = $0;
$conf_file_name =~ s/(\.pl)?$/\.conf/;
do "$conf_file_name";

my $all_methods;
foreach my $this_method_set ($top_methods, $diagonal_methods, $bottom_methods, $ignored_methods) {
  while (my ($key, $value) = each %$this_method_set) {
    $all_methods->{$key} = $value;
  }
}


my $usage = qq{
perl create_mlss_table.pl
  Getting help:
    [--help]
  
  General Configuration
    [--reg_conf registry_configuration_file]
        the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if
        defined, if not ~/.ensembl_init will be used.
    [--reg_url database_url]
        the url for the database. Registry will be loaded automatically
        from this database
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
use Getopt::Long;
my $reg_conf;
my $reg_url;
my $dbname = "compara";
my $method_link_type = undef;
my $list = undef;
my $blastz_net_list = undef;
my $trim = undef;
my $use_names = undef;
my $per_genome = undef;
my $output_file = undef;
my $species_tree_file = undef;
my $help;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "reg_url=s" => \$reg_url,
    "dbname=s" => \$dbname,
    "method_link_type=s@" => \$method_link_type,
    "list" => \$list,
    "blastz_list" => \$blastz_net_list,
    "trim" => \$trim,
    "use_names" => \$use_names,
    "per_genome" => \$per_genome,
    "output_file=s" => \$output_file,
    "species_tree_file=s" => \$species_tree_file,
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
if ($reg_url) {
  eval{ require Bio::EnsEMBL::Registry };
  Bio::EnsEMBL::Registry->load_registry_from_url($reg_url);
} elsif ($reg_conf) {
  # Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses ~/.ensembl_init
  # if all the previous fail.
  eval{ require Bio::EnsEMBL::Registry };
  Bio::EnsEMBL::Registry->load_all($reg_conf);
}
else {
  # Configuration necessary for this to run in web env ---------------
  use FindBin qw($Bin);
  use File::Path;
  use File::Basename qw( dirname );
  use vars qw( $SERVERROOT );
  BEGIN{
    $SERVERROOT = dirname( $Bin );
    $SERVERROOT =~ s#/ensembl-compara##;
    unshift @INC, "$SERVERROOT/conf";
    eval{ "require SiteDefs" };
    if ($@){ warn "Can't use SiteDefs.pm - $@\n"; }
    map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
  }

  require EnsEMBL::Web::SpeciesDefs;
  my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();
  my %db_multi = %{$SPECIES_DEFS->get_config("Multi","databases")};
  my $host   = $db_multi{ENSEMBL_COMPARA}{'HOST'};
  my $user   = $db_multi{ENSEMBL_COMPARA}{'USER'};
  my $passwd = "";
  my $port   = $db_multi{ENSEMBL_COMPARA}{'PORT'};
  my $db     = $db_multi{ENSEMBL_COMPARA}{'NAME'};

  Bio::EnsEMBL::Registry->load_registry_from_db(
				   -host    => $host,
				   -user    => $user,
                                   -pass    => $passwd,
                                   -port    => $port,
                                   -species => 'compara',
                                   -dbname  => $db );
}
use Bio::EnsEMBL::Utils::Exception qw(throw);

## Get the adaptor from the Registry
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');

my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');

my $ncbi_taxon_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'NCBITaxon');

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

#if defined species_tree_file, overwrite the species order given by the config
#file and use the species tree instead
if (defined $species_tree_file) {
    open(TREE_FILE, $species_tree_file) or throw("Cannot open file ".$species_tree_file);
    my $newick_species_tree = join("", <TREE_FILE>);
    close(TREE_FILE);
    $newick_species_tree =~ s/^\s*//;
    $newick_species_tree =~ s/\s*$//;
    $newick_species_tree =~ s/[\r\n]//g;
    my $species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick_species_tree);

    my $all_leaves = $species_tree->get_all_leaves;
    $species = undef;
    foreach my $this_leaf (@$all_leaves) {
	my $name = $this_leaf->name;
	$name =~ tr/_/ /d;
	my $spp;
	$spp->{long_name} = $name;
	my $genome_db;

	#not all species in the species tree are in the compara database so
	#need to check
	eval {
	    $genome_db = $genome_db_adaptor->fetch_by_name_assembly($name);
	};
	unless ($@) {
	    my $short_name = substr($genome_db->short_name, 0, 1) . "." . substr($genome_db->short_name, 1);
	    $spp->{short_name} = $short_name;
	}
	push @$species, $spp;
    }
}


foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
  foreach my $this_species (@{$this_method_link_species_set->species_set}) {
    next if ($this_species->{_found});

    foreach my $this_known_species (@$species) {
      if ($this_known_species->{long_name} eq $this_species->name) {
        $this_species->{_found} = 1;
	#print $this_species->name . "\n";
        last;
      }
    }
    if (!defined($this_species->{_found})) {
      die $this_species->name." has not been configured!";
    }
  }
}


if ($list and $per_genome) {
  print_html_list_per_genome($all_method_link_species_sets);
} elsif ($per_genome) {
  print_html_table_per_genome($all_method_link_species_sets);
} elsif ($list) {
  print_html_list($all_method_link_species_sets);
} elsif ($blastz_net_list) {
  print_blastz_net_list($all_method_link_species_sets);
} elsif ($method_link_type) {
  print_half_html_table($all_method_link_species_sets);
} else {
  print_full_html_table($all_method_link_species_sets);
}

exit(0);


#To be used instead for large BlastZ-net tables
my $ref_species;
sub print_blastz_net_list {
    my ($all_method_link_species_sets) = @_;

    #find reference species by parsing name field of mlss table
    foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
	
	if ($this_method_link_species_set->method_link_type ne "BLASTZ_NET") {
	    print "only to be used for BLASTZ_NET not " . $this_method_link_species_set->method_link_type . "\n";
	    next;
	}

	my ($short_ref_name) = $this_method_link_species_set->name =~ /\(on (.+)\)/;
	my $ref_genome_db = findGenomeDBFromShortName($short_ref_name); 

	#store the other species which also have this reference
	foreach my $this_species (@{$this_method_link_species_set->species_set}) {
	    if ($this_species->dbID != $ref_genome_db->dbID) {
		push @{$ref_species->{$ref_genome_db->dbID}}, $this_species->dbID;
	    }
	}
    }

    #In order of which species has most mlss entries, write the species and
    #then the other species in the order given in the species array which will 
    #be the species_tree if defined
    foreach my $ref_id (sort order_count_tree keys(%$ref_species)) {
	print "<h4>" . getNameString($ref_id) . "</h4>" . "\r\n";
	foreach my $other_id (sort order_tree @{$ref_species->{$ref_id}}) {
	    print getNameString($other_id) . "<br />" . "\r\n";
	}
    }
}

#order by firstly the number of mlss entries and then by the species_tree
sub order_count_tree {
    
    #$ref_species{$b}<=>$ref_species{$a};
    @{$ref_species->{$b}}<=>@{$ref_species->{$a}};

    return order_tree();
}

#order on species tree
sub order_tree {
    my $genome_db_a = $genome_db_adaptor->fetch_by_dbID($a);
    my $genome_db_b = $genome_db_adaptor->fetch_by_dbID($b);
    my $cnt = 0;
    my ($a_idx, $b_idx);
    foreach my $spp (@$species) {
	if ($spp->{long_name} eq $genome_db_a->name) {
	    $a_idx = $cnt;
	}
	if ($spp->{long_name} eq $genome_db_b->name) {
	    $b_idx = $cnt;
	}
	$cnt++;
    }
    return $a_idx <=> $b_idx;
}

#find the genome_db from the short name
sub findGenomeDBFromShortName {
    my ($short_name) = @_;

    my $all_genome_dbs = $genome_db_adaptor->fetch_all;
    $short_name =~ tr/\.//d;
    foreach my $genome_db (@$all_genome_dbs) {
	if ($genome_db->short_name eq $short_name) {
	    return $genome_db;
	}
    }
}

#Creates a string of the form ncbi ensembl alias name (genome_db->name)
#If the ncbi ensembl alias name does not exist, return the genome_db->name
sub getNameString {
    my ($genome_db_id) = @_;

    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
    my $ncbi_taxon = $ncbi_taxon_adaptor->fetch_node_by_taxon_id($genome_db->taxon_id);
    
    my $name;
    if ($ncbi_taxon->ensembl_alias_name) {
       $name = $ncbi_taxon->ensembl_alias_name . " (" . $genome_db->name . ")";
    } else {
	$name = $genome_db->name;
    }
    return $name;
}

sub print_html_list {
  my ($all_method_link_species_sets) = @_;

  @$all_method_link_species_sets = sort {
          ($a->method_link_id <=> $b->method_link_id) or ($a->name cmp $b->name)
      } @$all_method_link_species_sets;

  my $these_method_link_species_sets = [];

  foreach my $this_method_link_species_set (sort {scalar @{$a->species_set} <=> scalar @{$b->species_set}} @$all_method_link_species_sets) {
      print "<h4>",
	$this_method_link_species_set->name,
	  "</h4>\r\n";

      my $genome_ids;
      #store the other species which also have this reference
      foreach my $this_species (@{$this_method_link_species_set->species_set}) {
	  push @$genome_ids, $this_species->dbID;
      }
      foreach my $genome_id (sort order_tree @$genome_ids) {
	  print getNameString($genome_id) . "<br />" . "\n";
      }
      print "\r\n";
  }
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

  print qq{<table class="spreadsheet" style="width:auto">\r\n\r\n};
  
  print "<tr>\r\n<th></th>\r\n";
  for (my $i=0; $i<@$species; $i++) {
    my $formatted_name = $species->[$i]->{long_name};
    $formatted_name =~ s/ /<br>/g;
    print "<th><i>$formatted_name</i></th>\r\n";
  }
  print "<th></th>\r\n</tr>\r\n\r\n";
  
  for (my $i=0; $i<@$species; $i++) {
    print qq{<tr>\r\n<th class="left"><b><i>}, $species->[$i]->{short_name}, qq{</i></b></th>\r\n};
    for (my $j=0; $j<@$species; $j++) {
      my $all_method_link_species_sets = $table->{$species->[$i]->{long_name}}->{$species->[$j]->{long_name}};
      my $these_method_link_species_sets = [];
      if ($i > $j) {
        print qq{<td class="bg3 center">};
        foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
          if (defined($bottom_methods->{$this_method_link_species_set->method_link_type})) {
            push(@$these_method_link_species_sets, $this_method_link_species_set);
          }
        }
        @$these_method_link_species_sets = sort {$bottom_methods->{$a->method_link_type}->{order}
            <=> $bottom_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {
          if ($use_names) {
            $_->name
          } else {
            $bottom_methods->{$_->method_link_type}->{string}
          }} @$these_method_link_species_sets;
      } elsif ($i == $j) {
        print qq{<td class="center bg3">};
        foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
          if (defined($diagonal_methods->{$this_method_link_species_set->method_link_type})) {
            push(@$these_method_link_species_sets, $this_method_link_species_set);
          }
        }
        @$these_method_link_species_sets = sort {$diagonal_methods->{$a->method_link_type}->{order}
            <=> $diagonal_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {
          if ($use_names) {
            $_->name
          } else {
            $diagonal_methods->{$_->method_link_type}->{string}
          }} @$these_method_link_species_sets;
  #       foreach my $this_method_link (map {$_->method_link_type} @$all_method_link_species_sets) {
  #         if (defined($diagonal_methods->{$this_method_link})) {
  #           push(@$these_method_links, $this_method_link);
  #         }
  #       }
  #       @$these_method_links = sort {$diagonal_methods->{$a}->{order} <=> $diagonal_methods->{$b}->{order}}
  #           @$these_method_links;
  #       @$these_method_links = map {$diagonal_methods->{$_}->{string}} @$these_method_links;
      } else {
        print qq{<td class="center bg4">};
        foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
          if (defined($top_methods->{$this_method_link_species_set->method_link_type})) {
            push(@$these_method_link_species_sets, $this_method_link_species_set);
          }
        }
        @$these_method_link_species_sets = sort {$top_methods->{$a->method_link_type}->{order}
            <=> $top_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {
          if ($use_names) {
            $_->name
          } else {
            $top_methods->{$_->method_link_type}->{string}
          }} @$these_method_link_species_sets;
      }
      
      if (@$these_method_link_species_sets) {
        print join("<br />\r\n", @$these_method_link_species_sets);
      } else {
        print "-";
      }
      print qq{</td><!-- }, $species->[$j]->{short_name}, qq{ -->\r\n};
    }
    print qq{<td class="left"><b><i>}, $species->[$i]->{short_name}, qq{</i></b></td>\r\n};
    print "</tr>\r\n\r\n";
  }
  
  # print "<tr>\r\n\r\n<td> <br> <br> </td>\r\n\r\n";
  # for (my $i=0; $i<@$species; $i++) {
  #   my $formatted_name = $species->[$i]->{long_name};
  #   my $img_name = $species->[$i]->{img_name};
  #   my $img_url = $species->[$i]->{img_url};
  #   my $link_url = $formatted_name;
  #   $link_url =~ s/ /_/g;
  #   print qq!<td class="center bg3"><a href="/$link_url/" onmouseout="MM_swapImgRestore()" onmouseover="MM_swapImage('$img_name','','/gfx/rollovers/${img_name}1_do.gif',1)" target="external"><img id="$img_name" border="0" width="90" height="20" src="/gfx/rollovers/${img_name}1_up.gif" alt="Ensembl - $formatted_name" title="Ensembl - $formatted_name"></a></td>\r\n\r\n!;
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

  print qq{<table class="spreadsheet" style="width:auto">\r\n\r\n};
  
  for (my $i=0; $i<@$species; $i++) {
    if ($i % 2) {
      print qq{<tr>\r\n<td class="bg1 left"><b><i>}, $species->[$i]->{long_name}, qq{</i></b></td>\r\n};
    } else {
      print qq{<tr>\r\n<td class="bg3 left"><b><i>}, $species->[$i]->{long_name}, qq{</i></b></td>\r\n};
    }
    for (my $j=0; $j<$i; $j++) {
      my $all_method_link_species_sets = $table->{$species->[$i]->{long_name}}->{$species->[$j]->{long_name}};
      my $these_method_link_species_sets = [];
      if ($i % 2) {
        if ($j % 2) {
          print qq{<td class="bg1 center">};
        } else {
          print qq{<td class="bg3 center">};
        }
      } else {
        if ($j % 2) {
          print qq{<td class="bg3 center">};
        } else {
          print qq{<td class="bg4 center">};
        }
      }
      foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
        if (defined($all_methods->{$this_method_link_species_set->method_link_type})) {
          push(@$these_method_link_species_sets, $this_method_link_species_set);
        }
      }
      if (@$method_link_type == 1 && !$use_names) {
        @$these_method_link_species_sets = map {
          my $on_species = $_->name;
          $on_species =~ s/.*(\(.*\))/ $1/;
          $on_species = "" unless ($on_species =~ /^\s\(/);
          "<font color=\"blue\">YES$on_species</font>";
        } @$these_method_link_species_sets;
      } else {
        @$these_method_link_species_sets = sort {$all_methods->{$a->method_link_type}->{order}
            <=> $all_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
        @$these_method_link_species_sets = map {
            my $string;
            if ($use_names) {
              $string = $_->name;
            } else {
              $string = $all_methods->{$_->method_link_type}->{string}
            }
            if ($all_methods->{$_->method_link_type}->{bold}) {
              $string = "<b>$string</b>";
            }
            if ($all_methods->{$_->method_link_type}->{color}) {
            #  my $color = $all_methods->{$_->method_link_type}->{color};
            #  $string = "<font color=\"$color\">dd$string</font>";
	      $string;
            }
          } @$these_method_link_species_sets;
      }

      if (@$these_method_link_species_sets) {
        print join("<br />\r\n", @$these_method_link_species_sets);
      } else {
        print "-";
      }
      print qq{</td><!-- }, $species->[$j]->{short_name}, qq{ -->\r\n};
    }
    if ($i % 2) {
      print qq{<th class="bg1 center" style="width:5em"><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    } else {
      print qq{<th class="bg4 center" style="width:5em"><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    }
    print "</tr>\r\n\r\n";
  }
  
  print "<tr>\r\n<th></th>\r\n";
  for (my $i=0; $i<@$species; $i++) {
    if ($i % 2) {
      print qq{<th class="bg1 center" style="width:5em"><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    } else {
      print qq{<th class="bg3 center" style="width:5em"><i>}, $species->[$i]->{short_name}, "</i></th>\r\n";
    }
  }
  print "<th></th>\r\n</tr>\r\n\r\n";
  
  print "</table>\r\n";

}


sub print_html_list_per_genome {
  my ($all_method_link_species_sets) = @_;

  my $table;
  foreach my $this_method_link_species_set (@{$all_method_link_species_sets}) {
    my $genome_db_names;
    foreach my $genome_db (@{$this_method_link_species_set->species_set}) {
      my $genome_db_name = $genome_db->name;
      push (@$genome_db_names, $genome_db_name);
    }
    foreach my $genome_db_name (@$genome_db_names) {
      push(@{$table->{$genome_db_name}}, $this_method_link_species_set);
    }
  }

  print qq{<table class="spreadsheet" style="width:auto">\r\n\r\n};
  
  for (my $i=0; $i<@$species; $i++) {
    my $all_method_link_species_sets = $table->{$species->[$i]->{long_name}};
    my $these_method_link_species_sets = [];

    foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
      if (defined($all_methods->{$this_method_link_species_set->method_link_type})) {
        push(@$these_method_link_species_sets, $this_method_link_species_set);
      }
    }

    if (@$method_link_type == 1 and !$use_names) {
      @$these_method_link_species_sets = map {"Yes"} @$these_method_link_species_sets;
    } else {
      @$these_method_link_species_sets = sort {$all_methods->{$a->method_link_type}->{order}
          <=> $all_methods->{$b->method_link_type}->{order}} @$these_method_link_species_sets;
      @$these_method_link_species_sets = map {
	my $string;
	if ($use_names) {
	  $string = $_->name;
	} else {
	  $string = $all_methods->{$_->method_link_type}->{string}
	}
	if ($all_methods->{$_->method_link_type}->{bold}) {
	  $string = "<b>$string</b>";
	}
	if ($all_methods->{$_->method_link_type}->{color}) {
	  my $color = $all_methods->{$_->method_link_type}->{color};
	  $string = "<font color=\"$color\">$string</font>";
	}
      } @$these_method_link_species_sets;
    }

    if ($i % 2) {
      print qq{<tr>\r\n<td><i>}, $species->[$i]->{long_name}, qq{</i></td>\r\n};
      # print qq{<td class="bg1 center">};
      print qq{<td class="multi-cell1">};

    } else {
      print qq{<tr class="tint">\r\n<td class="multi-cell"><i>}, $species->[$i]->{long_name}, qq{</i></td>\r\n};
      #  print qq{<td class="bg3 center">};
      print qq{<td class="multi-cell2">};
    }

    if (@$these_method_link_species_sets) {
      print join("<br />\r\n", @$these_method_link_species_sets);
    } else {
      print "-";
    }
    print "</tr>\r\n\r\n";
  }

  print "</table>\r\n";

}


sub print_html_table_per_genome {
  my ($all_method_link_species_sets) = @_;

  my $table;
  foreach my $this_method_link_species_set (@{$all_method_link_species_sets}) {
    my $genome_db_names;
    foreach my $genome_db (@{$this_method_link_species_set->species_set}) {
      my $genome_db_name = $genome_db->name;
      push (@$genome_db_names, $genome_db_name);
    }
    foreach my $genome_db_name (@$genome_db_names) {
      $table->{$genome_db_name}->{$this_method_link_species_set->method_link_type} = 1;
    }
  }

  print qq{<table class="spreadsheet" style="width:auto">\r\n\r\n};

  print qq{<tr>\r\n<th>Species</th>\r\n};
  foreach my $this_method_link_type (@$method_link_type) {
    print "<th>", $all_methods->{$this_method_link_type}->{string}, "</th>\r\n";
  }
  print "</tr>\r\n\r\n";

  for (my $i=0; $i<@$species; $i++) {

    if ($i % 2) {
      print qq{<tr>\r\n<th><i>}, $species->[$i]->{long_name}, qq{</i></th>\r\n};

    } else {
      print qq{<tr class="tint">\r\n<th class="multi-header"><i>}, $species->[$i]->{long_name}, qq{</i></th>\r\n};
    }

    foreach my $this_method_link_type (@$method_link_type) {
      if ($table->{$species->[$i]->{long_name}}->{$this_method_link_type}) {
        print qq{<td class="multi-cell">Yes</td>\r\n};
      } else {
        print qq{<td class="multi-cell">-</td>\r\n};
      }
    }
    print "</tr>\r\n\r\n";
  }

  print "</table>\r\n";

}


