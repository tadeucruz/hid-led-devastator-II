//
//  main.m
//  hid-led-devastator-II
//
//  Created by Tadeu Cruz on 23/05/17.
//  Copyright © 2017 Tadeu Cruz. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <Carbon/Carbon.h>
#include <IOKit/hid/IOHIDLib.h>

static CFMutableDictionaryRef hu_CreateMatchingDictionaryUsagePageUsage( Boolean isDeviceNotElement,UInt32 inUsagePage,UInt32 inUsage )
{
    // create a dictionary to add usage page / usages to
    CFMutableDictionaryRef result = CFDictionaryCreateMutable( kCFAllocatorDefault,
                                                              0,
                                                              &kCFTypeDictionaryKeyCallBacks,
                                                              &kCFTypeDictionaryValueCallBacks );
    
    if ( result ) {
        if ( inUsagePage ) {
            // Add key for device type to refine the matching dictionary.
            CFNumberRef pageCFNumberRef = CFNumberCreate( kCFAllocatorDefault, kCFNumberIntType, &inUsagePage );
            
            if ( pageCFNumberRef ) {
                if ( isDeviceNotElement ) {
                    CFDictionarySetValue( result, CFSTR( kIOHIDDeviceUsagePageKey ), pageCFNumberRef );
                } else {
                    CFDictionarySetValue( result, CFSTR( kIOHIDElementUsagePageKey ), pageCFNumberRef );
                }
                CFRelease( pageCFNumberRef );
                
                // note: the usage is only valid if the usage page is also defined
                if ( inUsage ) {
                    CFNumberRef usageCFNumberRef = CFNumberCreate( kCFAllocatorDefault, kCFNumberIntType, &inUsage );
                    
                    if ( usageCFNumberRef ) {
                        if ( isDeviceNotElement ) {
                            CFDictionarySetValue( result, CFSTR( kIOHIDDeviceUsageKey ), usageCFNumberRef );
                        } else {
                            CFDictionarySetValue( result, CFSTR( kIOHIDElementUsageKey ), usageCFNumberRef );
                        }
                        CFRelease( usageCFNumberRef );
                    } else {
                        fprintf( stderr, "%s: CFNumberCreate( usage ) failed.", __PRETTY_FUNCTION__ );
                    }
                }
            } else {
                fprintf( stderr, "%s: CFNumberCreate( usage page ) failed.", __PRETTY_FUNCTION__ );
            }
        }
    } else {
        fprintf( stderr, "%s: CFDictionaryCreateMutable failed.", __PRETTY_FUNCTION__ );
    }
    return result;
}


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        //Genereico
        long product_id;
        long vendor_id;
        
        // create a IO HID Manager reference
        IOHIDDeviceRef * tIOHIDDeviceRefs = nil;
        IOHIDManagerRef tIOHIDManagerRef = IOHIDManagerCreate( kCFAllocatorDefault, kIOHIDOptionsTypeNone );
        
        // Create a device matching dictionary
        CFDictionaryRef matchingCFDictRef = hu_CreateMatchingDictionaryUsagePageUsage( TRUE, kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard );

        // set the HID device matching dictionary
        IOHIDManagerSetDeviceMatching( tIOHIDManagerRef, matchingCFDictRef );

        // Now open the IO HID Manager reference
        IOReturn tIOReturn = IOHIDManagerOpen( tIOHIDManagerRef, kIOHIDOptionsTypeNone );
        
        // and copy out its devices
        CFSetRef deviceCFSetRef = IOHIDManagerCopyDevices( tIOHIDManagerRef );
        
        // how many devices in the set?
        CFIndex deviceIndex, deviceCount = CFSetGetCount( deviceCFSetRef );

        // allocate a block of memory to extact the device ref's from the set into
        tIOHIDDeviceRefs = malloc( sizeof( IOHIDDeviceRef ) * deviceCount );

        // now extract the device ref's from the set
        CFSetGetValues( deviceCFSetRef, (const void **) tIOHIDDeviceRefs );

        // before we get into the device loop we'll setup our element matching dictionary
        matchingCFDictRef = hu_CreateMatchingDictionaryUsagePageUsage( FALSE, kHIDPage_LEDs, 0 );
        
        for ( deviceIndex = 0; deviceIndex < deviceCount; deviceIndex++ ) {
            // if this isn't a keyboard device...
            if ( !IOHIDDeviceConformsTo( tIOHIDDeviceRefs[deviceIndex], kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard ) ) {
                continue;	// ...skip it
            }
            
            CFNumberRef product = (CFNumberRef)IOHIDDeviceGetProperty(tIOHIDDeviceRefs[deviceIndex], CFSTR(kIOHIDProductIDKey));
            CFNumberRef vendor = (CFNumberRef)IOHIDDeviceGetProperty(tIOHIDDeviceRefs[deviceIndex], CFSTR(kIOHIDVendorIDKey));
            
            CFNumberGetValue((CFNumberRef)product, kCFNumberSInt32Type, &product_id);
            CFNumberGetValue(vendor, kCFNumberSInt32Type, &vendor_id);
            
            printf("Device = %p.\n", tIOHIDDeviceRefs[deviceIndex] );
            printf("PID:%04lX \n", product_id);
            printf("VID:%04lX \n", vendor_id);
            if (product_id == 1 && vendor_id == 9610) {
                CFArrayRef elementCFArrayRef = IOHIDDeviceCopyMatchingElements( tIOHIDDeviceRefs[deviceIndex], matchingCFDictRef, kIOHIDOptionsTypeNone );
                
                IOHIDElementRef tIOHIDElementRefNUMLK = ( IOHIDElementRef ) CFArrayGetValueAtIndex( elementCFArrayRef, 0 );
                IOHIDElementRef tIOHIDElementRefSCRLK = ( IOHIDElementRef ) CFArrayGetValueAtIndex( elementCFArrayRef, 2 );
                
                uint32_t usagePageNUMLK = IOHIDElementGetUsagePage( tIOHIDElementRefNUMLK );
                uint32_t usagePageSCRLK = IOHIDElementGetUsagePage( tIOHIDElementRefSCRLK );

                // if this isn't an LED element...
                if ( kHIDPage_LEDs != usagePageNUMLK ) {
                    continue;
                }
                
                if ( kHIDPage_LEDs != usagePageSCRLK ) {
                    continue;
                }
                
                CFIndex tCFIndex = 1;
                uint64_t timestamp = 0;
                
                IOHIDValueRef tIOHIDValueRefNUMLK = IOHIDValueCreateWithIntegerValue( kCFAllocatorDefault, tIOHIDElementRefNUMLK, timestamp, tCFIndex );
                IOHIDValueRef tIOHIDValueRefSCRLK = IOHIDValueCreateWithIntegerValue( kCFAllocatorDefault, tIOHIDElementRefSCRLK, timestamp, tCFIndex );
                
                tIOReturn = IOHIDDeviceSetValue( tIOHIDDeviceRefs[deviceIndex], tIOHIDElementRefNUMLK, tIOHIDValueRefNUMLK );
                tIOReturn = IOHIDDeviceSetValue( tIOHIDDeviceRefs[deviceIndex], tIOHIDElementRefSCRLK, tIOHIDValueRefSCRLK );
            }
        }
    }
    
    
    return 0;
}
