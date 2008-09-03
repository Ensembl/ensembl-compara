package Bio::EnsEMBL::GlyphSet::vegaclones;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Feature;
use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
use Bio::EnsEMBL::ExternalData::DAS::DAS;
use Bio::Das; 

use Data::Dumper;

@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

#this source is not used (v42) - redundant ?

sub my_label { return "Vega Clones"; }

sub features {
    my ($self)      = @_;
    return unless ref($self->species_defs->ENSEMBL_TRACK_DAS_SOURCES) eq 'HASH';
    my $slice       = $self->{'container'};
    my @clones      = ();

    ###### Create a list of clones to fetch #######
    foreach (@{$slice->get_tiling_path()}){
        my $clone = $_->component_Seq->clone->embl_id;
        push(@clones, $clone);
    }        

    ###### Get DAS source config for this track ######
    my $species_defs    = $self->species_defs();
    my $source          = "das_VEGACLONES";
    my $dbname          = $self->species_defs->ENSEMBL_TRACK_DAS_SOURCES->{$source};
    my $URL             = $dbname->{'url'};
    my $dsn             = $dbname->{'dsn'};
    my $types           = $dbname->{'types'} || [];
    my $adaptor         = undef;
    my %SEGMENTS        = ();
    ###### Register a callback function to handle the DAS features #######
    ###### Called whenever the DAS XML parser finds a feature      #######
    my $feature_callback =  sub {
        my $f = shift;
        return if (exists $SEGMENTS{$f->segment->ref().".".$f->segment->version()} );
        $SEGMENTS{$f->segment->ref().".".$f->segment->version()}++;
        #print STDERR "STORE: ", $f->segment->ref().".".$f->segment->version(), "\n";
    };
    ###### Create a new DAS adaptor #######
    eval {
        $URL = "http://$URL" unless $URL =~ /https?:\/\//i;
        $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new(
                                -url        => $URL,
                                -dsn        => $dsn,
                                -types      => $types || [], 
                                -proxy_url  => $self->species_defs->ENSEMBL_DAS_PROXY,
                                );
    };
    if($@) {
      warn("Vega Clones DASAdaptor creation error\n$@\n") 
    } 
       
    my $dbh 	    = $adaptor->_db_handle();
    my $response    = undef;
    $types          = []; # just for now....
    
    ###### DAS fetches happen here ##########
    if(1){     
       $response = $dbh->features(
                   -dsn         =>  "$URL/$dsn",
                   -segment     =>  \@clones,
                   -callback    =>  $feature_callback,
                   -type        =>  $types,
       );
    }
    
    ####### DAS URL debug trace ##########
    if(0){
        $response = $dbh->features(
                          -dsn        =>  "http://ecs3.internal.sanger.ac.uk:4001/das/$dsn",
                          -segment    =>  \@clones,
                          -callback   =>  $feature_callback,
                          -type       =>  $types,
        );
    }
    
    #print STDERR "SUCCESS\n" if $response->is_success;
    #print STDERR Dumper($response);
    #my $results = $response->results();
    #print STDERR "RESULTS: $results\n";
    #foreach my $seg (keys %{$results}){
    #    print STDERR "SEGMENT: $seg\n";
    #}
    
    my $res = [];
    foreach my $c (keys %SEGMENTS){
        my ($name,$ver) = split(/\./,$c);
        foreach my $p (@{$slice->get_tiling_path()}){
            if ($p->{contig}->name() =~ /$name/){
                my $s = Bio::EnsEMBL::Feature->new();
                
                # remember if the Vega clone version is newer/older/same as e! clone
                if($ver > $p->component_Seq->clone->embl_version){
                    $s->{'status'} = 1; # vega has newer clone version
                } elsif ($ver == $p->{contig}->clone->embl_version){
                    $s->{'status'} = 0; # vega has same clone version
                } else {
                    $s->{'status'} = -1;# vega has older clone version
                }
                my $id = $p->component_Seq->clone->embl_id() . "." . $p->component_Seq->clone->embl_version();
                my $label = $id . " >";
                if($p->{strand} == -1){
                    $label = "< "  . $id;
                }
                $s->id($label);
                $s->start($p->{start});
                $s->end($p->{end});
                $s->strand($p->{strand});
                $s->{'embl_clone'} = $c;
                push(@{$res}, $s,)
            }
        }
    }       
    return $res;
    
}

sub href {
    my ($self, $f ) = @_;
    return "http://vega.sanger.ac.uk/@{[$self->{container}{web_species}]}/$ENV{'ENSEMBL_SCRIPT'}?clone=".$f->{'embl_clone'}
}

sub colour {
    my ($self, $f ) = @_;
        if ($f->{'status'} > 0){
            return  $self->{'colours'}{"col1"},$self->{'colours'}{"lab1"},'border';
        } elsif ($f->{'status'} == 0) {
            return  $self->{'colours'}{"col2"},$self->{'colours'}{"lab2"},'border';
        } else {
            return  $self->{'colours'}{"col3"},$self->{'colours'}{"lab3"},'border';
        }
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->id,'overlaid');
}

sub zmenu {
    my ($self, $f ) = @_;
    my $zmenu = { 
        'caption' => "Vega Clones: ".$f->id,
        '01:bp: '.$f->start."-".$f->end => '',
        '02:length: '.($f->end-$f->start+1). ' bps' => '',
        '03:Jump to Vega' => $self->href($f),
    };
    return $zmenu;
}

1;
