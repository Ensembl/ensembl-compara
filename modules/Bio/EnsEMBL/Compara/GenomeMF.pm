=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


package Bio::EnsEMBL::Compara::GenomeMF;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Utils::IO::GFFParser;

use JSON;
use Bio::SeqIO;
use FileHandle;
use Data::Dumper;


sub new {
    my ($class, @args) = @_;

    my ($filename, $index);
    if (scalar @args) {
        ($filename, $index) = rearrange([qw(FILENAME INDEX)], @args);
    }

    die unless defined $filename;
    die unless defined $index;

    return $class->all_from_file($filename)->[$index-1];
}

sub all_from_file {
    my $self = shift;
    my $filename = shift;

    # Loads the file with JSON
    die "'filename' must be defined" unless defined $filename;
    die "Can't read from '$filename'" unless -r $filename;
    my $json_text   = `cat $filename`;
    my $json_parser = JSON->new->relaxed;
    my $perl_array   = $json_parser->decode($json_text);

    # List of fields that must / can be present
    my @obligatory_fields = qw(production_name taxonomy_id prot_fasta);
    my $possible_fields = {map {$_ => 1} (@obligatory_fields, qw(gene_coord_gff is_high_coverage has_karyotype))};

    # Checks the integrity of the file
    my $i = 0;
    die "The first level structure in '$filename' must be an array" unless ref($perl_array) eq 'ARRAY';
    foreach my $entry (@$perl_array) {
        die "The second level structures in '$filename' must be hashes" unless ref($entry) eq 'HASH';
        map {die "'$_' must map to a scalar in the registry file '$filename'" if ref($entry->{$_})} keys %$entry;
        map {die "'$_' is not a registered key in the registry file '$filename'" unless exists $possible_fields->{$_}} keys %$entry;
        map {die "'$_' must be present in every entry of the registry file '$filename'" unless exists $entry->{$_}} @obligatory_fields;
        $entry->{'_registry_file'} = $filename;
        $entry->{'_registry_index'} = ++$i;
        bless $entry, $self;
    }
    #print Dumper($perl_array);
    return $perl_array;
}

sub locator {
    my $self = shift;
    return sprintf('%s/filename=%s;index=%d', ref($self), $self->{'_registry_file'}, $self->{'_registry_index'});
}


## Coordinates

sub get_gene_coordinates {
    my $self = shift;
    $self->_load_coordinates unless exists $self->{'_gene_coordinates'};
    return $self->{'_gene_coordinates'}
}

sub get_cds_coordinates {
    my $self = shift;
    $self->_load_coordinates unless exists $self->{'_cds_coordinates'};
    return $self->{'_cds_coordinates'}
}

sub _load_coordinates {

    my $self = shift;

    my %gene_coordinates = ();
    my %cds_coordinates = ();
    if (exists $self->{'gene_coord_gff'}) {
        my $fh = FileHandle->new;
        $fh->open("<".$self->{'gene_coord_gff'});
        my $parser = Bio::EnsEMBL::Utils::IO::GFFParser->new($fh);
        $parser->parse_header();
        my $feature;
        while ($feature = $parser->parse_next_feature()) {
            my %feature = %{$feature};
            #print Dumper($feature);
            $gene_coordinates{ ${$feature{attribute}}{Name} } = [map {$feature{$_}} qw(seqid start end strand)] if $feature{type} eq 'mRNA';
            $cds_coordinates{ ${$feature{attribute}}{Name} } = [map {$feature{$_}} qw(seqid start end strand)] if $feature{type} eq 'match';
        }
    }
    print scalar(keys %gene_coordinates), " gene coordinates\n";
    print scalar(keys %cds_coordinates), " cds coordinates\n";
    $self->{'_gene_coordinates'} = \%gene_coordinates;
    $self->{'_cds_coordinates'} = \%cds_coordinates;
}


## Sequences

sub get_cds_sequences {
    my $self = shift;
    $self->_load_sequences('cds') unless exists $self->{'_cds_seq'};
    return $self->{'_cds_seq'};
}

sub get_protein_sequences {
    my $self = shift;
    $self->_load_sequences('prot') unless exists $self->{'_prot_seq'};
    return $self->{'_prot_seq'};
}

sub _load_sequences {
    my $self = shift;
    my $type = shift;

    my %sequence2hash = ();
    $self->{"_${type}_seq"} = \%sequence2hash;

    return unless exists $self->{"${type}_fasta"};
    my $input_file = $self->{"${type}_fasta"};
    die "Cannot find the file '$input_file'\n" unless -e $input_file;

    my $in_file  = Bio::SeqIO->new(-file => $input_file , '-format' => 'Fasta');
    while ( my $seq = $in_file->next_seq() ) {
        $sequence2hash{$seq->id} = $seq;
    }

    print scalar(keys %sequence2hash), " sequences of type $type\n";
    if(!keys(%sequence2hash)){
        die "Could not read fasta sequences from $input_file\n";
    }
}


## CoreDBAdaptor

sub get_GenomeContainer {
    my $self = shift;
    return $self;
}

sub get_MetaContainer {
    my $self = shift;
    return $self;
}


## GenomeDB fields

sub get_taxonomy_id {
    my $self = shift;
    return $self->{taxonomy_id};
}

sub get_genebuild {
    my $self = shift;
    return $self->{genebuild};
}

sub get_production_name {
    my $self = shift;
    return $self->{production_name};
}

sub has_karyotype {
    my $self = shift;
    return $self->{'has_karyotype'} || 0;
}

sub is_high_coverage {
    my $self = shift;
    return $self->{'is_high_coverage'} || 0;
}

sub assembly_name {
    my $self = shift;
    return $self->{'assembly'} || 'unknown_assembly';
}

1;

