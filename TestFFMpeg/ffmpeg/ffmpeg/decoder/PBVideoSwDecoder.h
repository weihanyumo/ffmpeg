
#import <UIKit/UIKit.h>
@interface PBVideoFrame : NSObject

@property(assign)char *videoData;
@property(assign)int dataLength;
@property(assign)int width;
@property(assign)int height;

@end

@interface PBVideoSwDecoder : NSObject
-(id)initWithDelegate:(id)aDelegate;
-(PBVideoFrame *)decodePackeg:(void *)packet;
@end

typedef struct adts_fixed_header {
    unsigned short syncword;    //            12;
    unsigned short ID;//                 1;
    unsigned short layer;//                2;
    unsigned short protection_absent;//        1;
    unsigned short profile;//:                  2;
    unsigned short sampling_frequency_index;//: 4;
    unsigned short private_bit;//:              1;
    unsigned short channel_configuration;//:    3;
    unsigned short original_copy;//:            1;
    unsigned short home;//:                     1;
} adts_fixed_header; // length : 28 bits

typedef struct adts_variable_header {
    unsigned char copyright_identification_bit:        1;
    unsigned char copyright_identification_start:    1;
    unsigned short aac_frame_length:                13;
    unsigned short adts_buffer_fullness:            11;
    unsigned char number_of_raw_data_blocks_in_frame:2;
} adts_variable_header; // length : 28 bits



