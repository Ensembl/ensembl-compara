=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
    my @obligatory_fields = qw(production_name taxonomy_id prot_fasta cds_fasta source);
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

sub get_coordinates {
    my $self = shift;

    $self->_load_coordinates unless exists $self->{'_coordinates'};
    return ($self->{'_gene_coordinates'}, $self->{'_cds_coordinates'})
}

sub _load_coordinates {
    my $self = shift;

    my %local_gene_coordinates = ();
    my %local_mrna_coordinates  = ();
    my %local_cds_coordinates  = ();
    my %gene_coordinates = ();
    my %cds_coordinates  = ();
    #my %gene_mapper = ();
    #my %mRNA_mapper = ();

    if ( exists $self->{'gene_coord_gff'} ) {
        my $fh = FileHandle->new;
        $fh->open( "<" . $self->{'gene_coord_gff'} ) || die "Could not open coordinates file (gff): " . $self->{'gene_coord_gff'};
        my $parser = Bio::EnsEMBL::Utils::IO::GFFParser->new($fh);
        $parser->parse_header();

        my $feature;
        my $parent;

        my $mitochondrial_genome;

        while ( $feature = $parser->parse_next_feature() ) {

            my %feature = %{$feature};

            if ( ( $self->{"source"} eq "refseq" ) || ( $self->{"source"} eq "augustus_maker") ) {

                #Check for mitochondrial genomes
                if ( ${ $feature{attribute} }{genome} ) {
                    if ( ${ $feature{attribute} }{genome} =~ /mitochondrion/ ) {
                        $mitochondrial_genome = 1;
                    }
                    if ( ${ $feature{attribute} }{genome} =~ /genomic/ ) {
                        $mitochondrial_genome = 0;
                    }
                }

                #get gene coordinates:
                $local_gene_coordinates{${ $feature{attribute} }{ID}} = [ map { $feature{$_} } qw(seqid start end strand) ] if $feature{type} eq 'gene';

                #get CDS or mRNA coordinates according to genome type
                if ($feature{type} eq 'CDS') {
                    if ( ${ $feature{attribute} }{Parent} ){
                        my $parent = ${ $feature{attribute} }{Parent} || warn "CDS does not have a parent:".${ $feature{attribute} }{ID}; #Some mito CDS may not have parents, so we should study closely.
                    }
                    else {
                        if ( $self->{"production_name"} eq "python_molurus_bivittatus" ) {
                            my $local_protein_id;
                            my $source = ${ $feature{attribute} }{Dbxref};
                            if ( $source =~ /Genbank:/ ) {
                                my @tok = split( /\:/, $source );
                                $local_protein_id = $tok[1];
                            }

                            my $local_id = ${ $feature{attribute} }{ID};
                            my $local_parent = "gene_$local_id";

                            $local_cds_coordinates{$local_id}{'parent'} = $local_parent;
                            $local_cds_coordinates{$local_id}{'coord'} = [ map { $feature{$_} } qw(seqid start end strand) ];
                            $local_cds_coordinates{$local_id}{'protein_id'} = $local_protein_id;

                            $local_gene_coordinates{$local_parent} = [ map { $feature{$_} } qw(seqid start end strand) ];
                        }
                    }

                    my $local_id = ${ $feature{attribute} }{ID};
                    my $protein_id;

                    #Tuatara has postfixes on the feature names (':cds' && ':exon')
                    if  ( $self->{"source"} eq "augustus_maker"){
                        my @tok = split(/\:/,$local_id);
                        $local_id = $tok[0];
                        $protein_id = $local_id;
                    }
                    else{
                        if (ref(${$feature{attribute}}{Dbxref}) eq 'ARRAY'){
                            foreach my $source ( @{ ${ $feature{attribute} }{Dbxref} } ) {
                                if ( $source =~ /Genbank:/ ) {
                                    my @tok = split( /\:/, $source );
                                    $protein_id = $tok[1];
                                }
                            }
                        }
                    }

                    if ( $self->{"production_name"} eq "ophiophagus_hannah" ) {
                        $protein_id = ${ $feature{attribute} }{protein_id};
                    }

                    if ($protein_id){
                        $local_cds_coordinates{$local_id}{'coord'} = [ map { $feature{$_} } qw(seqid start end strand) ];
                        $local_cds_coordinates{$local_id}{'parent'} = $parent;
                        $local_cds_coordinates{$local_id}{'protein_id'} = $protein_id;
                    }
                }

                if ($feature{type} eq 'mRNA'){
                    $parent = ${ $feature{attribute} }{Parent};
                    my $local_id = ${ $feature{attribute} }{ID};

                    #Tuatara has postfixes on the feature names (':cds' && ':exon')
                    if  ( $self->{"source"} eq "augustus_maker"){
                        my @tok = split(/\:/,$local_id);
                        $local_id = $tok[0];
                    }

                    $local_mrna_coordinates{$local_id}{'parent'} = $parent;
                    $local_mrna_coordinates{$local_id}{'coord'} = [ map { $feature{$_} } qw(seqid start end strand) ];
                }
            }
            elsif ( $self->{"source"} eq "gigascience" ) {
                    #if ( $self->{"production_name"} eq "ophisaurus_gracilis" ) {
                    #ophisaurus_gracilis gff file is very simple, the mRNA spams across the whole gene, so they have the same coordinates:

                    #get gene and cds coordinates:
                    $gene_coordinates{ ${ $feature{attribute} }{ID} } = [ map { $feature{$_} } qw(seqid start end strand) ] if $feature{type} eq 'mRNA';
                    $cds_coordinates{ ${ $feature{attribute} }{ID} } = [ map { $feature{$_} } qw(seqid start end strand) ] if $feature{type} eq 'mRNA';
                    #}
            }
        }
    }

    print scalar( keys %local_cds_coordinates ),  " LOCAL cds coordinates\n";
    print scalar( keys %local_mrna_coordinates ),  " LOCAL mrna coordinates\n";
    print scalar( keys %local_gene_coordinates ),  " LOCAL gene coordinates\n";

    if ( ( $self->{"source"} eq "refseq" ) || ( $self->{"source"} eq "augustus_maker" ) ) {

        #Build hierarchy
        foreach my $cds_id (keys %local_cds_coordinates){

            my $mRNA_id = $local_cds_coordinates{$cds_id}{'parent'};
            my $protein_id = $local_cds_coordinates{$cds_id}{'protein_id'};

            my $gene_id;
            #my $mRNA_len;

            #if mitochondrial the CDS will have as a parent a gene and not an mRNA
            if ($mRNA_id =~ /gene/){
                $gene_id = $mRNA_id;
                $mRNA_id = $cds_id;
                $cds_coordinates{$protein_id} = $local_cds_coordinates{$mRNA_id}{'coord'};
            }
            else{
                $gene_id = $local_mrna_coordinates{$mRNA_id}{'parent'};
                $cds_coordinates{$protein_id} = $local_mrna_coordinates{$mRNA_id}{'coord'};
            }

            $gene_coordinates{$protein_id} = $local_gene_coordinates{$gene_id}; 

        }
    }

    print scalar( keys %gene_coordinates ), " gene coordinates\n";
    print scalar( keys %cds_coordinates ),  " cds coordinates\n";

    $self->{'_gene_coordinates'} = \%gene_coordinates;
    $self->{'_cds_coordinates'}  = \%cds_coordinates;
}


## Sequences

sub get_sequences {
    my $self = shift;
    $self->_load_sequences();
    return ($self->{'_seqs'}{'prot'},$self->{'_seqs'}{'cds'});
}

sub _load_sequences {
    my $self = shift;

    foreach my $type ( @{ [ 'cds', 'prot' ] } ) {

        #sequence hash
        my %sequence2hash = ();
        $self->{'_seqs'}->{ ${type} } = \%sequence2hash;

        #Test if fasta file was declared and exists
        next unless exists $self->{"${type}_fasta"};
        my $input_file = $self->{"${type}_fasta"};
        die "Cannot find the file '$input_file'\n" unless -e $input_file;

        my $in_file = Bio::SeqIO->new( -file => $input_file, '-format' => 'Fasta' );
        while ( my $seq = $in_file->next_seq() ) {

            if ( ( $self->{"source"} eq "refseq" ) || ( $self->{"source"} eq "augustus_maker") ) {
                if ( $type eq "cds" ) {

                    my @fields = split( /\s+/, $seq->desc );

                    #Get protein ID
                    my $protein_id;
                    if ( $seq->desc =~ /protein_id=/ ) {
                        my @tok = split( /protein_id=/, $seq->desc );
                        my $tmp = $tok[1];
                        @tok = split( /\]/, $tmp );
                        $protein_id = $tok[0];
                    }
                    else{
                        $protein_id = $seq->id;
                    }

                    if ( $seq->desc =~ /gene=/ ) {
                        my @tok = split( /gene=/, $seq->desc );
                        my $tmp = $tok[1];
                        @tok = split( /\]/, $tmp );
                        $sequence2hash{$protein_id}{'display_name'} = $tok[0];
                    }
                    $sequence2hash{$protein_id}{'seq_obj'} = $seq;

                }
                else {
                    $sequence2hash{ $seq->id }{'seq_obj'} = $seq;
                }
            }
            elsif( $self->{"source"} eq "gigascience" ){
                $sequence2hash{ $seq->id }{'seq_obj'} = $seq;
                $sequence2hash{ $seq->id }{'display_name'} = $seq->id;
            }

            print scalar( keys %sequence2hash ), " sequences of type $type\n";
            if ( !keys(%sequence2hash) ) {
                die "Error while loading fasta sequences from $input_file\n";
            }
        }
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
