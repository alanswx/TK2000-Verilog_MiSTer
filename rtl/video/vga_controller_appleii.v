//
// A VGA line-doubler for an Apple ][
//
// Stephen A. Edwards, sedwards@cs.columbia.edu
//
//
// FIXME: This is all wrong
//
// The Apple ][ uses a 14.31818 MHz master clock.  It outputs a new
// horizontal line every 65 * 14 + 2 = 912 14M cycles.  The extra two
// are from the "extended cycle" used to keep the 3.579545 MHz
// colorburst signal in sync.  Of these, 40 * 14 = 560 are active video.
//
// In graphics mode, the Apple effectively generates 140 four-bit pixels
// output serially (i.e., with 3.579545 MHz pixel clock).  In text mode,
// it generates 280 one-bit pixels (i.e., with a 7.15909 MHz pixel clock).
//
// We capture 140 four-bit nibbles for each line and interpret them in
// one of the two modes.  In graphics mode, each is displayed as a
// single pixel of one of 16 colors.  In text mode, each is displayed
// as two black or white pixels.
//
///////////////////////////////////////////////////////////////////////////////

module vga_controller_appleii (
    input wire CLK_14M,       // 14.31818 MHz master clock
    input wire VIDEO,         // from the Apple video generator
    input wire COLOR_LINE,
    input wire [1:0] SCREEN_MODE, // 00: Color, 01: B&W, 10: Green, 11: Amber
    input wire HBL,
    input wire VBL,

    output reg VGA_HS,
    output reg VGA_VS,
    output VGA_HBL,
    output VGA_VBL,
    output reg [7:0] VGA_R,
    output reg [7:0] VGA_G,
    output reg [7:0] VGA_B
);

    // RGB values from Linards Ticmanis (posted on comp.sys.apple2 on 29-Sep-2005)
    // https://groups.google.com/g/comp.sys.apple2/c/uILy74pRsrk/m/G9XDxQhWi1AJ

      // Declare reg arrays to hold the color basis values
    reg [7:0] basis_r_data [0:3];
    reg [7:0] basis_g_data [0:3];
    reg [7:0] basis_b_data [0:3];

    // Initialize the arrays in an initial block
    initial begin
        // Assign the values to the reg arrays
        basis_r_data[0] = 8'h50;
        basis_r_data[1] = 8'h37;
        basis_r_data[2] = 8'h08;
        basis_r_data[3] = 8'h70;

        basis_g_data[0] = 8'h38;
        basis_g_data[1] = 8'h94;
        basis_g_data[2] = 8'h2C;
        basis_g_data[3] = 8'h07;

        basis_b_data[0] = 8'h38;
        basis_b_data[1] = 8'h10;
        basis_b_data[2] = 8'hB0;
        basis_b_data[3] = 8'h07;
    end

    reg [5:0] shift_reg;   // Last six pixels

    reg last_hbl;
    reg [10:0] hcount;
    reg [5:0] vcount;

    localparam VGA_HSYNC = 68;
    localparam VGA_ACTIVE = 282 * 2;
    localparam VGA_FRONT_PORCH = 130;

    localparam VBL_TO_VSYNC = 33;
    localparam VGA_VSYNC_LINES = 3;

    reg vbl_delayed;
    reg [17:0] de_delayed;

    always @(posedge CLK_14M) begin
        if (last_hbl == 1'b1 && HBL == 1'b0) begin  // Falling edge
            hcount <= 11'b0;
            vbl_delayed <= VBL;
            if (VBL == 1'b1) begin
                vcount <= vcount + 2'b01;
            end else begin
                vcount <= 6'b0;
            end
        end else begin
            hcount <= hcount + 2'b01;
        end
        last_hbl <= HBL;
    end

    always @(posedge CLK_14M) begin
        if (hcount == VGA_ACTIVE + VGA_FRONT_PORCH) begin
            VGA_HS <= 1'b1;
            if (vcount == VBL_TO_VSYNC) begin
                VGA_VS <= 1'b1;
            end else if (vcount == VBL_TO_VSYNC + VGA_VSYNC_LINES) begin
                VGA_VS <= 1'b0;
            end
        end else if (hcount == VGA_ACTIVE + VGA_FRONT_PORCH + VGA_HSYNC) begin
            VGA_HS <= 1'b0;
        end
    end

    always @(posedge CLK_14M) begin
        reg [7:0] r, g, b;

        shift_reg <= {VIDEO, shift_reg[5:1]};

        r = 8'h00;
        g = 8'h00;
        b = 8'h00;

        // alternate background for monochrome modes
        case (SCREEN_MODE)
            2'b00: begin r = 8'h00; g = 8'h00; b = 8'h00; end // color mode background
            2'b01: begin r = 8'h00; g = 8'h00; b = 8'h00; end // B&W mode background
            2'b10: begin r = 8'h00; g = 8'h0F; b = 8'h01; end // green mode background color
            2'b11: begin r = 8'h20; g = 8'h08; b = 8'h01; end // amber mode background color
        endcase

        if (COLOR_LINE == 1'b1) begin  // Monochrome mode
            if (shift_reg[2] == 1'b1) begin
                // handle green/amber color modes
                case (SCREEN_MODE)
                    2'b00: begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end // white (color mode)
                    2'b01: begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end // white (B&W mode)
                    2'b10: begin r = 8'h00; g = 8'hC0; b = 8'h01; end // green
                    2'b11: begin r = 8'hFF; g = 8'h80; b = 8'h01; end // amber
                endcase
            end
        end else if (shift_reg[0] == shift_reg[4] && shift_reg[1] == shift_reg[5]) begin
            if (shift_reg[1] == 1'b1) begin
                r = r + basis_r_data[hcount + 1]; // Use basis_r_data
                g = g + basis_g_data[hcount + 1]; // Use basis_g_data
                b = b + basis_b_data[hcount + 1]; // Use basis_b_data
            end
            if (shift_reg[2] == 1'b1) begin
                r = r + basis_r_data[hcount + 2]; // Use basis_r_data
                g = g + basis_g_data[hcount + 2]; // Use basis_g_data
                b = b + basis_b_data[hcount + 2]; // Use basis_b_data
            end
            if (shift_reg[3] == 1'b1) begin
                r = r + basis_r_data[hcount + 3]; // Use basis_r_data
                g = g + basis_g_data[hcount + 3]; // Use basis_g_data
                b = b + basis_b_data[hcount + 3]; // Use basis_b_data
            end
            if (shift_reg[4] == 1'b1) begin
                r = r + basis_r_data[hcount];     // Use basis_r_data
                g = g + basis_g_data[hcount];     // Use basis_g_data
                b = b + basis_b_data[hcount];     // Use basis_b_data
            end
        end else begin

            // Tint is changing: display only black, gray, or white
            case (shift_reg[3:2])
                2'b11: begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end
                2'b01, 2'b10: begin r = 8'h80; g = 8'h80; b = 8'h80; end
                default: begin r = 8'h00; g = 8'h00; b = 8'h00; end
            endcase
        end

        VGA_R <= r;
        VGA_G <= g;
        VGA_B <= b;

        de_delayed <= {de_delayed[16:0], last_hbl};
    end

    assign VGA_VBL = vbl_delayed;
    assign VGA_HBL = de_delayed[9] && de_delayed[17];

endmodule
