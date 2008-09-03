package Bio::EnsEMBL::GlyphSet::ensemblclones;

use strict;

use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::SimpleFeature;
use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
use Bio::EnsEMBL::ExternalData::DAS::DAS;
use Bio::Das; 

use EnsEMBL::Web::ExtURL;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label {

    my $self = shift;
    return $self->my_config('other') . " clones";
}

sub features {
    my $self = shift;
    return unless ref($self->species_defs->ENSEMBL_INTERNAL_DAS_SOURCES) eq 'HASH';
    
    my $slice = $self->{'container'};
    my @clones = ();

    # create a list of clones to fetch
    foreach my $segment (@{ $slice->project('clone') }){
        my $clone = $segment->to_Slice->seq_region_name;
        my ($clone_name) = split(/\./, $clone);
        push(@clones, {segment=>$clone_name,
					   type   => 'clone'});
    }
    # get DAS source config for this track
    my $species_defs    = $self->species_defs();
    my $source          = $self->my_config('dsn');
    my $dbname          = $self->species_defs->ENSEMBL_INTERNAL_DAS_SOURCES->{$source};
    return unless $dbname;
    my $URL             = $dbname->{'url'};
    my $dsn             = $dbname->{'dsn'};
    my $types           = $dbname->{'types'} || [];
    my $adaptor         = undef;
    my %SEGMENTS        = ();

    # register a callback function to handle the DAS features
    # called whenever the DAS XML parser finds a feature
    my $feature_callback =  sub {
        my $f = shift;
      $SEGMENTS{$f->{'feature_id'}}++;
    };

    # create a new DAS adaptor
    eval {
        $URL = "http://$URL" unless $URL =~ /https?:\/\//i;
        $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
                        -url        => $URL,
                        -dsn        => $dsn,
                        -types      => $types || [], 
                        -proxy_url  => $self->species_defs->ENSEMBL_DAS_PROXY,
        );
    };
    if ($@) {
        warn "Ensembl Clones DASAdaptor creation error: $@\n";
    }

    my $dbh = $adaptor->_db_handle();
    my $response;

    # DAS fetches happen here
    $response = $dbh->features(\@clones,$feature_callback);

    my $res = [];

    foreach my $seg (keys %SEGMENTS){
        my ($seg_name, $seg_version) = split(/\./, $seg);
        foreach my $p (@{ $slice->project('clone') }) {
            my $clone_slice = $p->to_Slice;
            my ($name, $version) = split(/\./, $clone_slice->seq_region_name);
            if ($name =~ /$seg_name/) {
                my $f = Bio::EnsEMBL::SimpleFeature->new(
                    -display_label  => $seg,
                    -start          => $p->from_start,
                    -end            => $p->from_end,
                    -strand         => $clone_slice->strand,
                );
                # remember if the e! clone version is newer/older/same as Vega
                # clone
                if ($seg_version > $version) {
                    $f->{'status'} = 'newer';
                } elsif ($seg_version == $version){
                    $f->{'status'} = 'same';
                } else {
                    $f->{'status'} = 'older';
                }
                push(@{$res}, $f);
            }
        }
    }
    return $res;
}

sub href {
  my ($self, $f) = @_;
  my ($cloneid) = split /\./ ,  $f->display_id;
  my $exturl = new EnsEMBL::Web::ExtURL( $self->species_defs->name,$self->species_defs );
  return $exturl->get_url(uc($self->my_config('other')))."@{[$self->{container}{web_species}]}/$ENV{'ENSEMBL_SCRIPT'}?clone=".$cloneid;
}

sub colour {
    my ($self, $f ) = @_;
    return $self->{'colours'}->{'col_'.$f->{'status'}},
           $self->{'colours'}->{'lab'};
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->display_id, 'overlaid');
}

sub zmenu {
    my ($self, $f ) = @_;
    my $zmenu = { 
        'caption' => $f->display_id,
        '03:status: '.$f->{'status'}.' version' => '',
        '04:Jump to '.$self->my_config('other') => $self->href($f),
    };
    return $zmenu;
}

1;
