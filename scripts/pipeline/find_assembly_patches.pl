#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

find_assembly_patches.pl

=head1 SYNOPSIS

 find_assembly_patches.pl --help  

 find_assembly_patches.pl 
    -new_core_url "mysql://ensro@ens-staging1:3306/homo_sapiens_core_68_37?group=core&species=homo_sapiens" 
    -prev_core_url "mysql://ensro@ens-livemirror:3306/homo_sapiens_core_67_37?group=core&species=homo_sapiens"
    -compara_url mysql://ensro@compara1:3306/mm14_ensembl_compara_master

=head1 DESCRIPTION

Find new, changed and deleted patches in the database defined by new_core_url with respect to the prev_core_url

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

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

=item B<--compara_url>

Location of the master database, used for finding the dnafrag_id of any CHANGED or DELETED patches. Must be of the format:
mysql://user@host:port/compara_database

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
my $compara_url;

GetOptions(
           "help" => \$help,
	   "new_core_url=s" => \$new_core,
	   "prev_core_url=s" => \$prev_core,
           "compara_url=s" => \$compara_url,
	  );

# Print Help and exit if help is requested
if ($help) {
  exec("/usr/bin/env perldoc $0");
}

my ($new_species, $new_core_patches) = get_patches($new_core);
my ($prev_species, $prev_core_patches) = get_patches($prev_core);

#$new_species and $prev_species should be the same
if ($new_species ne $prev_species) {
    die "The new_core species $new_species and prev_core species $prev_species are not the same";
}

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
my @dnafrags;
my @delete_names = ();
foreach my $name (keys %$changed_patches) {
    my ($new, $prev) = @{$changed_patches->{$name}};
    my $dnafrag = get_dnafrag($compara_url, $new_species, $name);
    print "  $name new=" . $new->{seq_region_id} . " " . $new->{date} . "\t";
    print "prev=" . $prev->{seq_region_id} . " " . $prev->{date} . "\t";
    print "dnafrag_id=" . $dnafrag->dbID . "\n";
    push @delete_names, "\"$name\"";
    push @dnafrags, $dnafrag->dbID;
}

print "DELETED patches\n";
foreach my $name (keys %$deleted_patches) {
    my $dnafrag = get_dnafrag($compara_url, $new_species, $name);
    print "  $name " . $deleted_patches->{$name}->{seq_region_id} . " " . $deleted_patches->{$name}->{date} . "\t";
    print "dnafrag_id=" . $dnafrag->dbID . "\n";
    push @delete_names, "\"$name\"";
    push @dnafrags, $dnafrag->dbID;
}

my $delete_str = @delete_names ? "(".(join ",", @delete_names).")" : "";
my $dnafrag_str = @dnafrags ? "(".(join ",", @dnafrags).")" : "";
print "\nDnaFrags to delete:\n";
print "  names: $delete_str\n";
print "  dnafrag_ids: $dnafrag_str\n";

if ($patch_names) {
    print "Input for create_patch_pairaligner_conf.pl:\n";
    chop $patch_names;
    print "--patches $patch_names\n";
}

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
    return ($params{-SPECIES}, $patches);
}

sub get_dnafrag {
    my ($compara_url, $species, $name) = @_;
    
    #get compara_dba from url
    my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);

    #get adapator from dba
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    my $genome_db = $genome_db_adaptor->fetch_by_registry_name($species);

    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
    return ($dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db, $name));
}
