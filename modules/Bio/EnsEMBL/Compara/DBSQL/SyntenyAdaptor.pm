

#
# Ensembl module for Bio::EnsEMBL::Compara::SyntenyAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SyntenyAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Compara::DBSQL::SyntenyAdaptor;
use vars qw(@ISA);
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::SyntenyRegion;
use strict;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub setSpecies {
    my( $self, $synteny_db, $species1, $species2 ) = @_;

    $species1 =~ tr/_/ /;
    $species2 =~ tr/_/ /;

    $self->{'_species_main'}      = $species1;
    $self->{'_species_secondary'} = $species2;
}

sub get_synteny_for_chromosome {
    my( $self, $chr, $start, $end ) = @_; # if chr = undef return all synteny pairs

    return [] if $self->{'_species_main'} eq $self->{'_species_secondary'};
    my @data = ();
    my $SYNTENY_DB = $self->{'_synteny_db'};
    my @parameters = ();
    my $extra_sql  = '';
    if(defined $chr ) {
      push @parameters, "$chr";
      $extra_sql .= " and df.name = ?";
      if(defined $start ) {
        push @parameters, $end, $start;
        $extra_sql .= " and dfr.seq_start <= ? and dfr.seq_end >= ?";
      }
    }
    my $sth =$self->prepare(
        "select sr.synteny_region_id,
                df.dnafrag_type as core_type,  df.name as core_name,
                dfr.seq_start as core_start,   dfr.seq_end as core_end,
                df_h.dnafrag_type as hit_type, df_h.name as hit_name,
                dfr_h.seq_start as hit_start,  dfr_h.seq_end as hit_end,
                sr.rel_orientation
           from dnafrag as df,         dnafrag as df_h,
                dnafrag_region as dfr, dnafrag_region as dfr_h,
                genome_db as gd,       genome_db as gd_h,
                synteny_region as sr
          where gd.name = ?   and gd.genome_db_id   = df.genome_db_id and
                gd_h.name = ? and gd_h.genome_db_id = df_h.genome_db_id and
                df.dnafrag_id   = dfr.dnafrag_id and
                df_h.dnafrag_id = dfr_h.dnafrag_id and
                dfr.synteny_region_id   = sr.synteny_region_id and
                dfr_h.synteny_region_id = sr.synteny_region_id $extra_sql
          order by df.name, dfr.seq_start          "
    );
    $sth->execute($self->{'_species_main'}, $self->{'_species_secondary'}, @parameters );
    while(my $Q = $sth->fetchrow_arrayref()) {
       push @data, new Bio::EnsEMBL::Compara::SyntenyRegion(
         {
            'synteny_id'    => $Q->[0],
            'seq_type'      => $Q->[1],     'chr_name'      => $Q->[2],
            'start'         => $Q->[3],    'end'       => $Q->[4],
            'chr_start'     => $Q->[3],     'chr_end'       => $Q->[4],
            'start'         => $Q->[3]-$start+1,     'end'           => $Q->[4]-$start+1,
            'hit_seq_type'  => $Q->[5],     'hit_chr_name'  => $Q->[6],
            'hit_chr_start' => $Q->[7],     'hit_chr_end'   => $Q->[8],
            'rel_ori'       => $Q->[9]
         } 
       ); 
    }
    return \@data;
}

1;

