#!/usr/bin/env perl

=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

 find_new_patches.pl

=head1 SYNOPSIS

 find_assembly_patches.pl --help  

 find_assembly_patches.pl 
    -new_core_url "mysql://ensro@ens-staging1:3306/homo_sapiens_core_68_37?group=core&species=homo_sapiens" 
    -prev_core_url "mysql://ensro@ens-livemirror:3306/homo_sapiens_core_67_37?group=core&species=homo_sapiens"

=head1 DESCRIPTION

Find new, changed and deleted patches in the database defined by new_core_url with respect to the prev_core_url

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=head2 GENERAL CONFIGURATION

=over

=item B<--new_core_url>

Location of the newest core database. Must be of the format:
mysql://user@host:port/species_core_db?group=core&species=species
eg mysql://ensro@ens-staging1:3306/homo_sapiens_core_68_37?group=core&species=homo_sapiens

=item B<--prev_core_url>

Location of the previous core database. Must be of the format:
mysql://user@host:port/species_core_db?group=core&species=species
eg mysql://ensro@ens-livemirror:3306/homo_sapiens_core_67_37?group=core&species=homo_sapiens

=back


=cut

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::URI qw/parse_uri/;
use Getopt::Long;

my $registry = 'Bio::EnsEMBL::Registry';

my $help;
my $new_core;
my $prev_core;

GetOptions(
           "help" => \$help,
	   "new_core_url=s" => \$new_core,
	   "prev_core_url=s" => \$prev_core,
	  );

# Print Help and exit if help is requested
if ($help) {
  exec("/usr/bin/env perldoc $0");
}

my $new_core_patches = get_patches($new_core);
my $prev_core_patches = get_patches($prev_core);

#Group patches together
my ($new_patches, $changed_patches, $deleted_patches);
my $patch_names;
foreach my $name (keys %$new_core_patches) {
    if (!defined $prev_core_patches->{$name}) {
	$patch_names .= $new_core_patches->{$name}->{coord_system} . ":" . $name . ",";
	$new_patches->{$name} = $new_core_patches->{$name};
    } else {
	if ($prev_core_patches->{$name}->{date} ne $new_core_patches->{$name}->{date}) {
	    $patch_names .= $new_core_patches->{$name}->{coord_system} . ":" . $name . ",";
	    push @{$changed_patches->{$name}}, $new_core_patches->{$name};
	    push @{$changed_patches->{$name}}, $prev_core_patches->{$name};
	}
    }
}

foreach my $name (keys %$prev_core_patches) {
    if (!defined $new_core_patches->{$name}) {
	$deleted_patches->{$name} = $prev_core_patches->{$name};
    } 
}

print "NEW patches\n";
foreach my $name (keys %$new_patches) {
    print "  $name " . $new_patches->{$name}->{seq_region_id} . " " . $new_patches->{$name}->{date} . "\n";
}

print "CHANGED patches\n";
my $delete_str = "(";
foreach my $name (keys %$changed_patches) {
    my ($new, $prev) = @{$changed_patches->{$name}};
    print "  $name new=" . $new->{seq_region_id} . " " . $new->{date} . "\t";
    print "prev=" . $prev->{seq_region_id} . " " . $prev->{date} . "\n";
    $delete_str .= "\"$name\",";
}

print "DELETED patches\n";
foreach my $name (keys %$deleted_patches) {
    print "  $name " . $deleted_patches->{$name}->{seq_region_id} . " " . $deleted_patches->{$name}->{date} . "\n";
    $delete_str .= "\"$name\",";
}
chop $delete_str; #remove final ,
$delete_str .= ")";

print "\nPatches to delete: $delete_str\n";

print "Input for create_patch_pairaligner_conf.pl:\n";
chop $patch_names;
print "--patches $patch_names\n";


sub get_patches {
    my ($core) = @_;

    my $uri = parse_uri($core);
    my %params = $uri->generate_dbsql_params();
    
    $params{-SPECIES} = $params{-DBNAME} unless $params{-SPECIES};
    
    my $new_core_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(%params);
    
    my $sql = "SELECT seq_region.seq_region_id, seq_region.name, value, coord_system.name FROM seq_region JOIN seq_region_attrib USING (seq_region_id) JOIN attrib_type USING (attrib_type_id) JOIN coord_system using (coord_system_id) WHERE code IN (\"patch_fix\", \"patch_novel\") ORDER BY value";
    
    my $sth = $new_core_dba->dbc->prepare($sql);
    $sth->execute();
    
    my ($seq_region_id, $seq_region_name, $date, $coord_system);
    $sth->bind_columns(\$seq_region_id, \$seq_region_name, \$date, \$coord_system);
    
    
    my $patches;
    while ($sth->fetch()) {
	#print "$seq_region_id $seq_region_name $value\n";
	my $patch;
	$patch->{'seq_region_id'} = $seq_region_id;
	$patch->{date} = $date;
	$patch->{coord_system} = $coord_system,

	$patches->{$seq_region_name} = $patch;
    }
    return $patches;
}
