=head1 NAME

Bio::EnsEMBL::GlyphSet::glovar_haplotype -
Glyphset to draw haplotype blocks

=head1 DESCRIPTION

This glyphset fetches haplotype data from Glovar and draws haplotype blocks.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::glovar_haplotype;
use strict;
use vars qw(@ISA);
use Digest::MD5 qw(md5_hex);
use Bio::EnsEMBL::GlyphSet_simple;

@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

=head2 my_label

  Arg[1]      : none
  Example     : my $label = $self->my_label;
  Description : returns the label for the track (displayed track name)
  Return type : String - track label
  Exceptions  : none
  Caller      : $self->init_label()

=cut

sub my_label { return "Haplotypes"; }

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : This function does the data fetching from the Glovar database.
                Since all data is retrieved on individual clones from Glovar
                but haplotypes might span multiple clones, they have to be
                stitched together here.
  Return type : listref of Bio::EnsEMBL::ExternalData::Glovar::Haplotype objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my ($self) = @_;
    my @haplotypes = @{ $self->{'container'}->get_all_ExternalFeatures('GlovarHaplotype') };
    return [] unless @haplotypes;

    # stitch haplotypes spanning multiple clones together (they are returned as
    # individual objects with the same dbID by the DBAdaptor)
    my $haps;
    foreach my $h (@haplotypes) {
        if (my $last = $haps->{$h->dbID}) {
        # we've seen this haplotype before
            # adjust start/end
            $last->start($h->start) if ($last->start > $h->start);
            $last->end($h->end) if ($last->end < $h->end);
            
            # add tagSNPs
            map { $last->add_tagSNP($_->{'start'}, $_->{'end'}) }
                    $h->get_all_tagSNPs;
        } else {
        # first time
            $haps->{$h->dbID} = $h;
        }
    }

    my @haplist = map { $haps->{$_} } keys %$haps;
    return \@haplist;
}

=head2 colour

  Arg[1]      : Bio::EnsEMBL::ExternalData::Glovar::Haplotype object
  Example     : my $colour = $self->colour($f);
  Description : sets the colour for displaying haplotypes. The colour is
                dynamically generated from the population name
  Return type : List of glyph colour, label colour, glyph style
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub colour {
    my ($self, $f) = @_;
    # create a reproducable random colour from the population
    # (possible improvement: exclude very light and very dark colours)
    my $hex = substr(md5_hex($f->population), 0, 6);
    my $colour = $self->{'config'}->colourmap->add_hex($hex);
    return ($colour, $colour, 'line');
}

=head2 tag

  Arg[1]      : Bio::EnsEMBL::ExternalData::Glovar::Haplotype object
  Example     : my @tags = $self->tag($haplotype);
  Description : draws the haplotype's tagSNPs
  Return type : List of tags
  Exceptions  : none
  Caller      : Bio::EnsEMBL::Glyphset_simple

=cut

sub tag {
    my ($self, $f) = @_;
    my @tags;
    my @colours = $self->colour($f);
    foreach my $t ($f->get_all_tagSNPs) {
        push @tags, {
          'style'  => 'rect',
          'colour' => $colours[0],
          'start'  => $t->{'start'} - $self->{'container'}->start + 1,
          'end'    => $t->{'end'} - $self->{'container'}->start + 1,
        };
    }
    return @tags;
}

=head2 href

  Arg[1]      : Bio::EnsEMBL::ExternalData::Glovar::Haplotype object
  Example     : my $href = $self->href($f);
  Description : returns a href
  Return type : String - href
  Exceptions  : none
  Caller      : $self->_init(), $self->zmenu()

=cut

sub href { 
    my ($self, $f) = @_;
    return $self->ID_URL( 'GLOVAR_HAPLOTYPE', $f->dbID );
}

=head2 zmenu

  Arg[1]      : Bio::EnsEMBL::ExternalData::Glovar::Haplotype object
  Example     : my $zmenu = $self->zmenu($f);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub zmenu {
    my ($self, $f) = @_;
    return {
        'caption' => $f->display_id,
        '01:Haplotype block ID: '.$f->display_id => '',
        '02:Sample: '.$f->population => '',
        '03:Block size: '.$f->length.' bp' => '',
        '04:No. SNPs: '.$f->num_snps => '',
        '05:Source: Glovar' => '',
        "06:Haplotype Report" => $self->href($f),
    };
}
1;
