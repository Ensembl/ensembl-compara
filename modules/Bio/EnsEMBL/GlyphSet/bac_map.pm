package Bio::EnsEMBL::GlyphSet::bac_map;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "BAC map"; }

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    my $max_full_length  = $self->{'config'}->get( "bac_map", 'full_threshold' ) || 200000000;
    return 
      map { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
          map { [$_->seq_start-$_->state*1e9, $_] }
            $self->{'container'}->get_all_MapFrags(
              $container_length > $max_full_length ? 'acc_bac_map' : 'bac_map'
            );
}

sub colour {
    my ($self, $f) = @_;
    my $state = substr($f->state,3);
    return ( $self->{'colours'}{"col_$state"}, $self->{'colours'}{"lab_$state"});
}

sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=".$f->name
}

sub image_label {
    my ($self, $f ) = @_;
    return ($f->name,'overlaid');
}

sub zmenu {
    my ($self, $f ) = @_;
    my $zmenu = { 
        'caption' => "Clone: ".$f->name,
        '01:bp: '.$f->seq_start."-".$f->seq_end => '',
        '02:length: '.$f->length.' bps' => '',
        '03:Centre on clone:' => $self->href($f),
    };
    $zmenu->{'12:EMBL: '.$f->embl_acc      } = ''             if($f->embl_acc);
    $zmenu->{'13:Organisation: '.$f->organisation} = '' if($f->organisation);
    $zmenu->{'14:State: '.substr($f->state,3)        } = ''              if($f->state);
    $zmenu->{'15:Seq length: '.$f->seq_len } = ''        if($f->seq_len);    
    $zmenu->{'16:FP length:  '.$f->fp_size } = ''        if($f->fp_size);    
    $zmenu->{'17:super_ctg:  '.$f->superctg} = ''       if($f->superctg);    
    $zmenu->{'18:BAC flags'.$f->BACend_flag.': '.$f->bacinfo } = ''    if($f->BACend_flag);    
    return $zmenu;
}

1;
